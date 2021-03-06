--  GHDL driver for synthesis
--  Copyright (C) 2016 Tristan Gingold
--
--  GHDL is free software; you can redistribute it and/or modify it under
--  the terms of the GNU General Public License as published by the Free
--  Software Foundation; either version 2, or (at your option) any later
--  version.
--
--  GHDL is distributed in the hope that it will be useful, but WITHOUT ANY
--  WARRANTY; without even the implied warranty of MERCHANTABILITY or
--  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
--  for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with GCC; see the file COPYING.  If not, write to the Free
--  Software Foundation, 59 Temple Place - Suite 330, Boston, MA
--  02111-1307, USA.

with GNAT.OS_Lib; use GNAT.OS_Lib;

with Types; use Types;
with Ghdllocal; use Ghdllocal;
with Ghdlcomp; use Ghdlcomp;
with Ghdlmain; use Ghdlmain;
with Options; use Options;
with Errorout;
with Errorout.Console;
with Version;
with Default_Paths;

with Libraries;
with Flags;
with Vhdl.Nodes; use Vhdl.Nodes;
with Vhdl.Errors;
with Vhdl.Scanner;
with Vhdl.Std_Package;
with Vhdl.Canon;
with Vhdl.Configuration;
with Vhdl.Annotations;
with Vhdl.Utils;

with Netlists.Dump;
with Netlists.Disp_Vhdl;

with Synthesis;
with Synth.Disp_Vhdl;

package body Ghdlsynth is
   type Out_Format is (Format_Raw, Format_Vhdl);

   --  Command --synth
   type Command_Synth is new Command_Lib with record
      Disp_Inline : Boolean := True;
      Oformat : Out_Format := Format_Vhdl;
   end record;
   function Decode_Command (Cmd : Command_Synth; Name : String)
                           return Boolean;
   function Get_Short_Help (Cmd : Command_Synth) return String;
   procedure Decode_Option (Cmd : in out Command_Synth;
                            Option : String;
                            Arg : String;
                            Res : out Option_State);
   procedure Perform_Action (Cmd : Command_Synth;
                             Args : Argument_List);

   function Decode_Command (Cmd : Command_Synth; Name : String)
                           return Boolean
   is
      pragma Unreferenced (Cmd);
   begin
      return Name = "--synth";
   end Decode_Command;

   function Get_Short_Help (Cmd : Command_Synth) return String
   is
      pragma Unreferenced (Cmd);
   begin
      return "--synth [FILES... -e] UNIT [ARCH]   Synthesis from UNIT";
   end Get_Short_Help;

   procedure Decode_Option (Cmd : in out Command_Synth;
                            Option : String;
                            Arg : String;
                            Res : out Option_State) is
   begin
      if Option = "--disp-noinline" then
         Cmd.Disp_Inline := False;
         Res := Option_Ok;
      elsif Option = "--out=raw" then
         Cmd.Oformat := Format_Raw;
         Res := Option_Ok;
      elsif Option = "--out=vhdl" then
         Cmd.Oformat := Format_Vhdl;
         Res := Option_Ok;
      else
         Decode_Option (Command_Lib (Cmd), Option, Arg, Res);
      end if;
   end Decode_Option;

   --  Init, analyze and configure.
   --  Return the top configuration.
   function Ghdl_Synth_Configure (Args : Argument_List) return Node
   is
      use Vhdl.Errors;
      use Vhdl.Configuration;
      use Errorout;
      E_Opt : Integer;
      Opt_Arg : Natural;
      Design_File : Iir;
      Config : Iir;
      Top : Iir;
      Prim_Id : Name_Id;
      Sec_Id : Name_Id;
   begin
      --  If the '-e' switch is present, there is a list of files.
      E_Opt := Args'First - 1;
      for I in Args'Range loop
         if Args (I).all = "-e" then
            E_Opt := I;
            exit;
         end if;
      end loop;

      Vhdl.Annotations.Flag_Synthesis := True;
      Vhdl.Scanner.Flag_Comment_Keyword := True;
      Vhdl.Scanner.Flag_Pragma_Comment := True;

      Common_Compile_Init (False);
      --  Will elaborate.
      Flags.Flag_Elaborate := True;
      Flags.Flag_Elaborate_With_Outdated := E_Opt >= Args'First;
      Flags.Flag_Only_Elab_Warnings := True;

      Libraries.Load_Work_Library (E_Opt >= Args'First);

      --  Do not canon concurrent statements.
      Vhdl.Canon.Canon_Flag_Concurrent_Stmts := False;

      --  Analyze files (if any)
      for I in Args'First .. E_Opt - 1 loop
         Design_File := Ghdlcomp.Compile_Analyze_File2 (Args (I).all);
      end loop;
      pragma Unreferenced (Design_File);

      if Nbr_Errors > 0 then
         --  No need to configure if there are missing units.
         return Null_Iir;
      end if;

      --  Elaborate
      if E_Opt = Args'Last then
         --  No unit.
         Top := Vhdl.Configuration.Find_Top_Entity (Libraries.Work_Library);
         if Top = Null_Node then
            Ghdlmain.Error ("no top unit found");
            return Null_Iir;
         end if;
         Errorout.Report_Msg (Msgid_Note, Option, No_Source_Coord,
                              "top entity is %i", (1 => +Top));
         if Nbr_Errors > 0 then
            --  No need to configure if there are missing units.
            return Null_Iir;
         end if;
         Prim_Id := Get_Identifier (Top);
         Sec_Id := Null_Identifier;
      else
         Extract_Elab_Unit ("--synth", Args (E_Opt + 1 .. Args'Last), Opt_Arg,
                            Prim_Id, Sec_Id);
         if Opt_Arg <= Args'Last then
            Ghdlmain.Error ("extra options ignored");
            return Null_Iir;
         end if;
      end if;

      Config := Vhdl.Configuration.Configure (Prim_Id, Sec_Id);

      if Nbr_Errors > 0 then
         --  No need to configure if there are missing units.
         return Null_Iir;
      end if;

      Vhdl.Configuration.Add_Verification_Units;

      --  Check (and possibly abandon) if entity can be at the top of the
      --  hierarchy.
      declare
         Entity : constant Iir :=
           Vhdl.Utils.Get_Entity_From_Configuration (Config);
      begin
         Vhdl.Configuration.Check_Entity_Declaration_Top (Entity, False);
         if Nbr_Errors > 0 then
            return Null_Iir;
         end if;
      end;

      --  Annotate all units.
      Vhdl.Annotations.Annotate (Vhdl.Std_Package.Std_Standard_Unit);
      for I in Design_Units.First .. Design_Units.Last loop
         Vhdl.Annotations.Annotate (Design_Units.Table (I));
      end loop;

      return Config;
   end Ghdl_Synth_Configure;

   function Ghdl_Synth (Argc : Natural; Argv : C_String_Array_Acc)
                       return Module
   is
      Args : Argument_List (1 .. Argc);
      Res : Module;
      Cmd : Command_Acc;
      First_Arg : Natural;
      Config : Node;
   begin
      --  Create arguments list.
      for I in 0 .. Argc - 1 loop
         declare
            Arg : constant Ghdl_C_String := Argv (I);
         begin
            Args (I + 1) := new String'(Arg (1 .. strlen (Arg)));
         end;
      end loop;

      --  Find the command.  This is a little bit convoluted...
      Decode_Command_Options ("--synth", Cmd, Args, First_Arg);

      --  Do the real work!
      Config := Ghdl_Synth_Configure (Args (First_Arg .. Args'Last));
      if Config = Null_Iir then
         return No_Module;
      end if;

      Res := Synthesis.Synth_Design (Config);
      return Res;

   exception
      when Option_Error =>
         return No_Module;
      when others =>
         --  Avoid possible issues with exceptions...
         return No_Module;
   end Ghdl_Synth;

   procedure Perform_Action (Cmd : Command_Synth;
                             Args : Argument_List)
   is
      Res : Module;
      Config : Iir;
      Ent : Iir;
   begin
      Config := Ghdl_Synth_Configure (Args);

      if Config = Null_Iir then
         raise Errorout.Compilation_Error;
      end if;

      Res := Synthesis.Synth_Design (Config);
      if Res = No_Module then
         raise Errorout.Compilation_Error;
      end if;

      case Cmd.Oformat is
         when Format_Raw =>
            Netlists.Dump.Flag_Disp_Inline := Cmd.Disp_Inline;
            Netlists.Dump.Disp_Module (Res);
         when Format_Vhdl =>
            if Boolean'(True) then
               Ent := Vhdl.Utils.Get_Entity_From_Configuration (Config);
               Synth.Disp_Vhdl.Disp_Vhdl_Wrapper (Ent, Res);
            else
               Netlists.Disp_Vhdl.Disp_Vhdl (Res);
            end if;
      end case;
   end Perform_Action;

   function Get_Libghdl_Name return String
   is
      Libghdl_Version : String := Version.Ghdl_Ver;
   begin
      for I in Libghdl_Version'Range loop
         if Libghdl_Version (I) = '.' or Libghdl_Version (I) = '-' then
            Libghdl_Version (I) := '_';
         end if;
      end loop;
      return "libghdl-" & Libghdl_Version
        & Default_Paths.Shared_Library_Extension;
   end Get_Libghdl_Name;

   function Get_Libghdl_Path return String is
   begin
      if Ghdllocal.Exec_Prefix = null then
         --  Compute install path (only once).
         Ghdllocal.Set_Exec_Prefix_From_Program_Name;
      end if;

      return Ghdllocal.Exec_Prefix.all & Directory_Separator & "lib"
        & Directory_Separator & Get_Libghdl_Name;
   end Get_Libghdl_Path;

   function Get_Libghdl_Include_Dir return String is
   begin
      --  Compute install path
      Ghdllocal.Set_Exec_Prefix_From_Program_Name;

      return Ghdllocal.Exec_Prefix.all & Directory_Separator & "include";
   end Get_Libghdl_Include_Dir;

   procedure Register_Commands is
   begin
      Ghdlmain.Register_Command (new Command_Synth);
      Register_Command
        (new Command_Str_Disp'
           (Command_Type with
            Cmd_Str => new String'
              ("--libghdl-name"),
            Help_Str => new String'
              ("--libghdl-name  Display libghdl name"),
            Disp => Get_Libghdl_Name'Access));
      Register_Command
        (new Command_Str_Disp'
           (Command_Type with
            Cmd_Str => new String'
              ("--libghdl-library-path"),
            Help_Str => new String'
              ("--libghdl-library-path  Display libghdl library path"),
            Disp => Get_Libghdl_Path'Access));
      Register_Command
        (new Command_Str_Disp'
           (Command_Type with
            Cmd_Str => new String'
              ("--libghdl-include-dir"),
            Help_Str => new String'
              ("--libghdl-include-dir  Display libghdl include directory"),
            Disp => Get_Libghdl_Include_Dir'Access));
   end Register_Commands;

   procedure Init_For_Ghdl_Synth is
   begin
      Ghdlsynth.Register_Commands;
      Options.Initialize;
      Errorout.Console.Install_Handler;
   end Init_For_Ghdl_Synth;
end Ghdlsynth;

--  Locations for instances.
--  Copyright (C) 2019 Tristan Gingold
--
--  This file is part of GHDL.
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 51 Franklin Street - Fifth Floor, Boston,
--  MA 02110-1301, USA.

with Tables;

package body Netlists.Locations is
   package Loc_Table is new Tables
     (Table_Component_Type => Location_Type,
      Table_Index_Type => Instance,
      Table_Low_Bound => No_Instance,
      Table_Initial => 1024);

   procedure Set_Location1 (Inst : Instance; Loc : Location_Type)
   is
      Cur_Last : constant Instance := Loc_Table.Last;
   begin
      if Inst > Cur_Last then
         Loc_Table.Set_Last (Inst);
         for I in Cur_Last + 1 .. Inst - 1 loop
            Loc_Table.Table (I) := No_Location;
         end loop;
      end if;
      Loc_Table.Table (Inst) := Loc;
   end Set_Location1;

   procedure Set_Location (Inst : Instance; Loc : Location_Type) is
   begin
      if Flag_Locations then
         Set_Location1 (Inst, Loc);
      end if;
   end Set_Location;

   function Get_Location1 (Inst : Instance) return Location_Type is
   begin
      if Inst > Loc_Table.Last then
         return No_Location;
      else
         return Loc_Table.Table (Inst);
      end if;
   end Get_Location1;

   function Get_Location (Inst : Instance) return Location_Type is
   begin
      if Flag_Locations then
         return Get_Location1 (Inst);
      else
         return No_Location;
      end if;
   end Get_Location;
begin
   Loc_Table.Append (No_Location);
end Netlists.Locations;

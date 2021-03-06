--  Nodes recognizer for ieee.math_real.
--  Copyright (C) 2019 Tristan Gingold
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
--  along with GHDL; see the file COPYING.  If not, write to the Free
--  Software Foundation, 59 Temple Place - Suite 330, Boston, MA
--  02111-1307, USA.

package Vhdl.Ieee.Math_Real is
   Math_Real_Pkg : Iir_Package_Declaration := Null_Iir;

   --  Extract declarations from PKG (ieee.math_real).
   procedure Extract_Declarations (Pkg : Iir_Package_Declaration);
end Vhdl.Ieee.Math_Real;

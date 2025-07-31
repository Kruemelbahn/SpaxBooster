@ECHO .
@ECHO .   ***   ****    *   *   *
@ECHO .  *      *   *  * *   * *
@ECHO .   ***   ****  *****   *
@ECHO .      *  *     *   *  * *
@ECHO .   ***   *     *   * *   * ALARM
@ECHO .
@ECHO . build file for version 1.0
@ECHO .
@REM set installation directory of assembler
@REM 
SET MPASM="%MPLAB%\mpasmwin.exe"
@REM
cd SHMDBoost
if "%1" == "clean" GOTO :clean
if "%1" == "distclean" GOTO :distclean
%MPASM% shboost-alarm.asm
GOTO :fin
:distclean
ERASE *.HEX
:clean
ERASE *.COD
ERASE *.ERR
ERASE *.LST
:fin





@REM    Build SHBOOST with this batchfile
@REM 
@REM    MPASM from microchip is required!
@REM    This is part of the MPLAB installation.
@REM 
@REM    Customize here:
@REM
@REM ***** set installation directory of assembler *****
@REM SET MPASM_HOME=D:\Programme\microchip\asm21500
@REM SET MPASM_HOME=C:\Programme\microchip\MPASM Suite
SET MPASM_HOME=%MPLAB%
@REM 
@REM ***** select assembler (depends on your os) *******
@REM SET MPASM=%MPASM_HOME%\mpasm.exe
@REM SET MPASM=%MPASM_HOME%\mpasm_dp.exe
SET MPASM=%MPASM_HOME%\mpasmwin.exe
@REM
@REM ***************************************************
@REM $Log: build.bat,v $
@REM Revision 1.3  2007/02/09 19:13:12  pischky
@REM build version for all processors in one batch run
@REM
@REM Revision 1.2  2007/02/09 17:47:51  pischky
@REM values from wiso readout back to sourcefile (this are the testet values)
@REM
@REM Revision 1.1  2007/02/01 21:40:33  pischky
@REM added build.bat, generate INHX8M outputfile
@REM
@REM
@REM change to MY directory
cd SHMDBoost
@REM
if "%1" == "clean" GOTO :clean
if "%1" == "distclean" GOTO :distclean
%MPASM% shboost-alarm.asm
GOTO :fin
:distclean
ERASE *.HEX
:clean
ERASE *.COD
ERASE *.ERR
ERASE *.LST
:fin

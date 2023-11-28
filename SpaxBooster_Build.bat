@ECHO .
@ECHO .   ***   ****    *   *   *
@ECHO .  *      *   *  * *   * *
@ECHO .   ***   ****  *****   *
@ECHO .      *  *     *   *  * *
@ECHO .   ***   *     *   * *   * ALARM
@ECHO .
@ECHO . build file for version 4.0
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

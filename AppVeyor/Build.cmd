@echo off
if not "%3"=="VS2017" call "%vs140comntools%vsvars32.bat"
if     "%3"=="VS2017" call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat"

dir "C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\atlmfc\include\afxwin.h"
dir "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\afxwin*.h" /s
set include=%include%;"C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\atlmfc\include";"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.13.26128\atlmfc\include"

powershell -ExecutionPolicy Unrestricted .\Build.ps1 %1 %2 %3 %4 %5 %6 %7 %8 %9

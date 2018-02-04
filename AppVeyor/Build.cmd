@echo off
if not "%3"=="VS2013" call "C:\Program Files (x86)\Microsoft Visual Studio 11.0\VC\vcvarsall.bat" x86
if     "%3"=="VS2013" call "%vs140comntools%vsvars32.bat"

powershell -ExecutionPolicy Unrestricted .\Build.ps1 %1 %2 %3 %4

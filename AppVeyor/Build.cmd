@echo off
rem "C:\Program Files (x86)\Microsoft Visual Studio 11.0\VC\vcvarsall.bat" x86
    call "%vs120comntools%vsvars32.bat"

powershell -ExecutionPolicy Unrestricted .\Build.ps1 %1 %2 %3 %4

echo Ejecutar PEDRO-ESTADOS

TASKKILL /IM UiPath.Service.UserHost.exe /F
TASKKILL /IM UiPath.RobotJS.UserHost.exe /F
TASKKILL /IM UiPath.Executor.exe /F
TASKKILL /IM UiPath.Agent.exe /F
TASKKILL /IM UiPath.Assistant.exe /F

@echo echo Se ejecutara PEDRO-ESTADOS
:
@echo off

TIMEOUT /T 10

cd C:\Users\MULTICASH\AppData\Local\Programs\UiPath\Studio
UiRobot.exe -p PEDRO_ESTADOS

TIMEOUT /T 15

exit

@echo off
REM Flutter Clean and Rebuild Script for Windows
REM Run this in your Flutter project root directory

echo Cleaning Flutter project...
flutter clean

echo Deleting build folder...
rmdir /s /q build

echo Deleting Gradle cache...
rmdir /s /q android\.gradle

echo Getting dependencies...
flutter pub get

echo Done! You can now run: flutter run
pause

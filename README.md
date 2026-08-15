# Chocolatey Packages

This repository is a fork of the original project by [tomflynn83](https://github.com/tomflynn83/chocolatey-packages), which was outdated. I have taken over as the maintainer of this repository, and it is now the official source for these Chocolatey packages.

This project was initially created using the [chocolatey/chocolatey-packages-template](https://github.com/chocolatey/chocolatey-packages-template).

This contains Chocolatey packages, both manually and automatically maintained. Automatic packaging uses [Chocolatey-AU](https://github.com/chocolatey-community/chocolatey-au), the community maintained fork of AU (Automatic Updater).

A GitHub Actions workflow runs daily: it updates the packages, commits the changes, and pushes new package versions to chocolatey.org.

## Folder Structure

* automatic - where automatic packaging and packages are kept. These are packages that are automatically maintained using [Chocolatey-AU](https://github.com/chocolatey-community/chocolatey-au).
* icons - Where you keep icon files for the packages. This is done to reduce issues when packages themselves move around.
* manual - where packages that are not automatic are kept.
* setup - items for prepping the system to ensure for auto packaging.

For setting up your own automatic package repository, please see [Automatic Packaging](https://chocolatey.org/docs/automatic-packages)

## Requirements

* Chocolatey (choco.exe)
* PowerShell v5+.
* The [Chocolatey-AU module](https://www.powershellgallery.com/packages/Chocolatey-AU).

For daily operations check out the AU packages [template README](https://github.com/majkinetor/au-packages-template/blob/master/README.md).

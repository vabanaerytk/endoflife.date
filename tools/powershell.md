---
permalink: /powershell
layout: post
title: PowerShell
command: pwsh -v
link: https://docs.microsoft.com/powershell/scripting/powershell-support-lifecycle
changelogTemplate: https://github.com/PowerShell/PowerShell/blob/master/CHANGELOG/__RELEASE_CYCLE__.md
releaseDateColumn: true
sortReleasesBy: "releaseCycle"
eolColumn: Support Status
releases:
  - releaseCycle: 6.0
    release: 2018-01-10
    eol: 2019-02-13
    latest: 6.0.5
  - releaseCycle: 6.1
    release: 2018-09-13
    eol: 2019-09-28
    latest: 6.1.5
  - releaseCycle: 6.2
    release: 2019-03-28
    eol: 2020-09-04
    latest: 6.2.4
  - releaseCycle: 7.0
    release: 2020-03-04
    eol: false
    latest: 7.0.0
    lts: true
---

> [PowerShell Core](https://aka.ms/powershell)  is a cross-platform (Windows, Linux, and macOS) automation and configuration tool/framework that works well with your existing tools and is optimized for dealing with structured data (e.g. JSON, CSV, XML, etc.), REST APIs, and object models. It includes a command-line shell, an associated scripting language and a framework for processing cmdlets.

Microsoft publishes new major releases of PowerShell Core on a regular cadence, enabling developers, the community and businesses to plan their roadmaps. 

6.2 will EOL 6 months after 7.0 releases.

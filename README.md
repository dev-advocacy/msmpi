# Microsoft MPI

Microsoft MPI (MS-MPI) is a Microsoft implementation of the [Message Passing Interface standard](https://www.mpi-forum.org) for developing and running parallel applications on the Windows platform.

MS-MPI offers several benefits:

  - Ease of porting existing code that uses [MPICH](https://www.mpich.org).
  - Security based on Active Directory Domain Services.
  - High performance on the Windows operating system.
  - Binary compatibility across different types of interconnectivity options.

## Version of MPI standard 

MS-MPI is MPI 2.2 compliant with the exception of Fortran bindings errata around attributes interop between C and Fortran. MS-MPI implements a subset of features from MPI 3.1 standard:
  - Non-blocking collectives,
  - RMA,
  - MPI shared memory,
  - New datatypes,
  - Large counts,
  - Matched probe.

For the full list of APIs please see [Microsoft MPI Reference](https://docs.microsoft.com/en-us/message-passing-interface/microsoft-mpi).

## MS-MPI downloads

The following are current downloads for MS-MPI:

  - [MS-MPI v10.0](https://www.microsoft.com/download/details.aspx?id=57467) (new\!) - see [Release notes](microsoft-mpi-release-notes.md)
  - The MS-MPI SDK is also available on [Nuget](https://www.nuget.org/packages/msmpisdk/).

Earlier versions of MS-MPI are available from the [Microsoft Download Center](https://go.microsoft.com/fwlink/p/?linkid=390734).

##  Community resources

  - [Windows HPC MPI Forum](https://social.microsoft.com/forums/en-us/home?forum=windowshpcmpi)
  - [Contact the MS-MPI Team](mailto:askmpi@microsoft.com)

## Microsoft high performance computing resources

  - Featured tutorial: [How to compile and run a simple MS-MPI program](https://blogs.technet.com/b/windowshpc/archive/2015/02/02/how-to-compile-and-run-a-simple-ms-mpi-program.aspx)
  - Featured guide: [Set up a Windows RDMA cluster with HPC Pack and A8 and A9 instances to run MPI applications](https://azure.microsoft.com/documentation/articles/virtual-machines-windows-hpcpack-cluster-rdma/)
  - [Microsoft High Performance Computing for Developers](https://msdn.microsoft.com/en-us/library/ff976568.aspx)
  - [Microsoft HPC Pack (Windows HPC Server) Technical Library](https://technet.microsoft.com/library/cc514029)
  - [Azure HPC Scenarios](https://www.microsoft.com/hpc)

# Building

These instructions describe the current Windows x64/x86 build configuration.
Run the commands below in a **Developer Command Prompt for Visual Studio**,
not a plain Command Prompt. Do not run IDE and command-line builds against the
same output directories at the same time.

## Requirements

- Windows x64 and Visual Studio 2026 with **Desktop development with C++**,
  the MSVC **v145** x64/x86 build tools, and MSBuild. Install **.NET desktop
  development** for the legacy .NET Framework/CBT build tooling.
- Windows SDK **10.0.26100.0**, including the resource compiler (`rc.exe`),
  message compiler (`mc.exe`), and MIDL. The original build also lists the
  Windows WDK as a prerequisite for its legacy tooling.
- GNU Fortran (`gfortran.exe`) capable of producing Windows x64 and x86
  (`-m32`) objects. `Directory.Build.props` defaults `GFORTRAN_BIN` to
  `C:\Strawberry\c\bin`; change it or pass `/p:GFORTRAN_BIN="C:\path\to\bin"`.
- Perl on `PATH` (`perl.exe`), for generated MPI messages and Fortran COFF
  compatibility processing. The current environment uses Strawberry Perl.
- NuGet access, or an existing local cache, for **NetworkDirect 2.0.1**.
  The package is referenced by the DLL, channels, and device projects.
- For the installer: **WiX Toolset 3.14** build tools with `WixUIExtension`
  and `WixUtilExtension`. A compatible Visual Studio WiX extension is needed
  only to open/build the WiX project in the IDE; command-line builds use the
  installed WiX MSBuild targets.

`Directory.Build.props` selects the Windows SDK and output directories.
The projects and installer currently select v145; pass
`/p:PlatformToolset=<installed-toolset>` consistently if retargeting the build.
ARM64 is not configured in this tree.

The repository includes CommonBuildToolset (CBT) build infrastructure.
`RestoreCBTModules` is currently `false` in `Directory.Build.props` because
optional CBT module feeds were unavailable in this environment. The commands
below build through `src\msmpi.sln` and the native project files instead of
relying on a root traversal build.

## Restore dependencies

Start in the source directory (adjust the checkout path if necessary):

```bat
cd /d C:\Dev\MSPI\Microsoft-MPI-10.1.1\Microsoft-MPI-10.1.1\src
msbuild mpi\msmpi\dll\msmpi.vcxproj /t:Restore /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v145 /p:RestoreSources=https://api.nuget.org/v3/index.json
msbuild mpi\msmpi\dll\msmpi.vcxproj /t:Restore /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /p:RestoreSources=https://api.nuget.org/v3/index.json
```

Restore is needed for a fresh checkout or changed dependencies. If the feed
is inaccessible, restore from an approved reachable feed or use a populated
local package cache; a failed restore is not a successful build.

## Compile the runtime and launchers

From the same `src` directory:

```bat
msbuild msmpi.sln /t:msmpi;msmpiLaunchSvc;mpiexec;smpd /p:Configuration=Release /p:Platform=x64 /p:PlatformToolset=v145 /m /nr:false
msbuild mpi\msmpi\dll\msmpi.vcxproj /t:Build /p:Configuration=Release /p:Platform=x86 /p:PlatformToolset=v145 /m /nr:false
```

The first command builds the x64 runtime and launchers and their dependencies.
The second builds the x86 runtime required by the x64 installer. These are
selected runtime targets, not a claim that every legacy solution target builds.
For a native Debug build, substitute `Configuration=Debug`; the installer
still packages Release native binaries.

Paths below are relative to the checkout root, one directory above `src`:

| Output | Location |
|---|---|
| x64 runtime | `out\Release-x64\msmpi\msmpi.dll` |
| x86 runtime | `out\Release-x86\msmpi\msmpi.dll` |
| x64 launchers | `out\Release-x64\mpiexec\mpiexec.exe`, `out\Release-x64\smpd\smpd.exe`, `out\Release-x64\msmpiLaunchSvc\msmpiLaunchSvc.exe` |
| Staged runtime files and trace manifest | `out\Release-x64\bin`, `out\Release-x86\bin` |

## Compile the MSI installer

The installer is a sibling project outside this checkout, at
`C:\Dev\MSPI\msmpisetup`. Keep that layout, or update `MpiSourceRoot` in
`SetupProject1.wixproj` and the relative static-file paths in `Product.wxs`.
The following seven original redistributable files must exist in `src\bin`:

- `IMB_MPI1.exe`, `IMB_NBC.exe`, `MpiPingpong.exe`.
- `msmpires.dll`, `msmpires64.dll`.
- `MicrosoftMPI_Redistributable_EULA.rtf`, `MPI_Redistributables_TPN.txt`.

They are packaging inputs, not outputs of this solution. The icon is still
referenced at `C:\temp\1e5b4e3\Icon\MSIICON`; that file must also exist, or its
`SourceFile` in `Product.wxs` must be updated before building.

```bat
msbuild C:\Dev\MSPI\msmpisetup\SetupProject1.wixproj /t:Build /p:Configuration=Release /p:Platform=x86 /m:1 /nr:false
```

This automatically builds the Release native x64 targets and the x86 DLL,
then produces `C:\Dev\MSPI\msmpisetup\bin\Release\SetupProject1.msi`.
The WiX project configuration is named `x86`, but `Product.wxs` declares an
**x64 MSI** containing both x64 and x86 runtime DLLs.

To build in Visual Studio, open `src\msmpi.sln`, select the desired native
configuration, and build the selected runtime projects or `SetupProject1`.
For the installer, its Release x86 project configuration invokes both native
Release builds automatically.

## Troubleshooting

- Close a running installer before rebuilding its MSI. If the output is locked,
  close the application holding it, or build a separate file with
  `/p:OutputName=SetupProject1-Check`; do not run concurrent builds.
- `LGHT1105` means system policy prevented MSI ICE validation. The MSI may be
  generated, but ICE validation has **not** passed. Validate in an environment
  where that validation is permitted; do not treat it as an installation test.
- After building, test installation on a suitable test machine. Successful
  compilation alone does not verify upgrades, services, or firewall changes.

## Versioned Windows installer

The native binary version is defined in `src\mpi.props` and is currently
`10.1.12498.53`. The DLL and launcher resource scripts use
`src\include\mpiversion.h` to embed the same file and product version.

The local WiX project at `..\..\msmpisetup\SetupProject1.wixproj` builds the
Release x64 runtime and launchers and the Release x86 runtime, regardless of
the installer configuration. It packages executables from the `smpd`, `mpiexec`,
and `msmpiLaunchSvc` subdirectories of `out\Release-x64`, and DLLs from the
`msmpi` subdirectories of `out\Release-x64` and `out\Release-x86`.
The trace manifest comes from `out\Release-x64\bin`.
It requires WiX v3 with the UI and Util extensions and defaults to the v145
C++ toolset (override `PlatformToolset` when using another supported toolset).
Benchmarks, resource-only DLLs, and license documents from the original package
are stored in `src\bin` and retain their original versions. The installer icon
still comes from `C:\temp\1e5b4e3\Icon\MSIICON`.

The GNU Fortran build uses `Set-FortranCoffDirectives.pl` to give its
`.drectve` section the MSVC linker-information attributes and remove GNU
`-aligncomm` hints that MSVC ignores. Other directives are preserved and the
section is kept out of the final image. NetworkDirect 2.0.1 does not ship
`ndutil.pdb`, so `msmpi.vcxproj` suppresses LNK4099 only for its DLL link;
NetworkDirect source-level debug symbols remain unavailable.

The MSI product name, registry values, and upgrade bounds are updated in
`Product.wxs` alongside the native version. Windows Installer compares only
the first three version fields: upgrades between `.52` and `.53` therefore
use a new ProductCode and inclusive same-version upgrade detection. The fourth
field cannot provide MSI downgrade protection.

# Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

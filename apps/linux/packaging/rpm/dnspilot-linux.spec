Name: dnspilot
Version: 0.1.0
Release: 1%{?dist}
Summary: DNS benchmark and resolver guidance
License: MIT
URL: https://dnspilot.io
Source0: dnspilot-linux-gui
Source1: dnspilot-linux-shell
Source2: dnspilot-cli
Source3: io.dnspilot.DNSPilot.desktop
Source4: io.dnspilot.DNSPilot.metainfo.xml
Source5: io.dnspilot.DNSPilot.svg

%description
DNS Pilot benchmarks DNS resolvers, manages custom DNS profiles, renders
diagnostics, and provides store-safe manual DNS settings guidance. Native DNS
mutation is unavailable in this build.

%prep

%build

%install
install -Dm755 %{SOURCE0} %{buildroot}%{_bindir}/dnspilot-linux-gui
install -Dm755 %{SOURCE1} %{buildroot}%{_bindir}/dnspilot-linux-shell
install -Dm755 %{SOURCE2} %{buildroot}%{_bindir}/dnspilot-cli
install -Dm644 %{SOURCE3} %{buildroot}%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
install -Dm644 %{SOURCE4} %{buildroot}%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
install -Dm644 %{SOURCE5} %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg

%files
%{_bindir}/dnspilot-linux-gui
%{_bindir}/dnspilot-linux-shell
%{_bindir}/dnspilot-cli
%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg

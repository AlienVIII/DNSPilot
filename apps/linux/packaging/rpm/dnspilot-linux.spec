Name: dnspilot
Version: 0.1.0
Release: 1%{?dist}
Summary: DNS benchmark and native resolver guidance
License: MIT
URL: https://dnspilot.io
Source0: dnspilot-linux-gui
Source1: dnspilot-linux-shell
Source2: dnspilot-cli
Source3: dnspilot-native-helper
Source4: io.dnspilot.DNSPilot.desktop
Source5: io.dnspilot.DNSPilot.metainfo.xml
Source6: io.dnspilot.DNSPilot.svg
Source7: io.dnspilot.DNSPilot.apply.policy

Recommends: polkit
Recommends: NetworkManager
Suggests: systemd-resolved

%description
DNS Pilot benchmarks DNS resolvers, manages custom DNS profiles, renders
diagnostics, and can use a native helper path for DNS apply when the resolver
stack and polkit authorization are available.

%prep

%build

%install
install -Dm755 %{SOURCE0} %{buildroot}%{_bindir}/dnspilot-linux-gui
install -Dm755 %{SOURCE1} %{buildroot}%{_bindir}/dnspilot-linux-shell
install -Dm755 %{SOURCE2} %{buildroot}%{_bindir}/dnspilot-cli
install -Dm755 %{SOURCE3} %{buildroot}%{_libexecdir}/dnspilot/dnspilot-native-helper
install -Dm644 %{SOURCE4} %{buildroot}%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
install -Dm644 %{SOURCE5} %{buildroot}%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
install -Dm644 %{SOURCE6} %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg
install -Dm644 %{SOURCE7} %{buildroot}%{_datadir}/polkit-1/actions/io.dnspilot.DNSPilot.apply.policy

%files
%{_bindir}/dnspilot-linux-gui
%{_bindir}/dnspilot-linux-shell
%{_bindir}/dnspilot-cli
%{_libexecdir}/dnspilot/dnspilot-native-helper
%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg
%{_datadir}/polkit-1/actions/io.dnspilot.DNSPilot.apply.policy

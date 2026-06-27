Name: dnspilot
Version: 0.1.0
Release: 1%{?dist}
Summary: DNS benchmark and native resolver guidance
License: MIT
URL: https://dnspilot.io

Requires: polkit
Requires: NetworkManager

%description
DNS Pilot benchmarks DNS resolvers, manages custom DNS profiles, renders
diagnostics, and can use a native helper path for DNS apply when the resolver
stack and polkit authorization are available.

%prep

%build

%install
install -Dm755 dnspilot-linux-shell %{buildroot}%{_bindir}/dnspilot-linux-shell
install -Dm755 dnspilot-native-helper %{buildroot}%{_libexecdir}/dnspilot/dnspilot-native-helper
install -Dm644 io.dnspilot.DNSPilot.desktop %{buildroot}%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
install -Dm644 io.dnspilot.DNSPilot.metainfo.xml %{buildroot}%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
install -Dm644 io.dnspilot.DNSPilot.svg %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg
install -Dm644 io.dnspilot.DNSPilot.apply.policy %{buildroot}%{_datadir}/polkit-1/actions/io.dnspilot.DNSPilot.apply.policy

%files
%{_bindir}/dnspilot-linux-shell
%{_libexecdir}/dnspilot/dnspilot-native-helper
%{_datadir}/applications/io.dnspilot.DNSPilot.desktop
%{_datadir}/metainfo/io.dnspilot.DNSPilot.metainfo.xml
%{_datadir}/icons/hicolor/scalable/apps/io.dnspilot.DNSPilot.svg
%{_datadir}/polkit-1/actions/io.dnspilot.DNSPilot.apply.policy

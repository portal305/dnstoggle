class DnsServer {
  final String id;
  final String name;
  final String primaryDns;
  final String? secondaryDns;
  final bool isCustom;
  final int? latencyMs;

  DnsServer({
    required this.id,
    required this.name,
    required this.primaryDns,
    this.secondaryDns,
    this.isCustom = false,
    this.latencyMs,
  });

  DnsServer copyWith({
    String? id,
    String? name,
    String? primaryDns,
    String? secondaryDns,
    bool? isCustom,
    int? latencyMs,
  }) {
    return DnsServer(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryDns: primaryDns ?? this.primaryDns,
      secondaryDns: secondaryDns ?? this.secondaryDns,
      isCustom: isCustom ?? this.isCustom,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryDns': primaryDns,
      'secondaryDns': secondaryDns,
      'isCustom': isCustom,
    };
  }

  factory DnsServer.fromJson(Map<String, dynamic> json) {
    return DnsServer(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryDns: json['primaryDns'] as String,
      secondaryDns: json['secondaryDns'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  static List<DnsServer> get defaultServers => [
    DnsServer(
      id: 'cloudflare',
      name: 'Cloudflare DNS',
      primaryDns: '1dot1dot1dot1.cloudflare-dns.com',
      isCustom: false,
    ),
    DnsServer(
      id: 'google',
      name: 'Google Public DNS',
      primaryDns: 'dns.google',
      isCustom: true,
    ),
    DnsServer(
      id: 'adguard',
      name: 'AdGuard DNS',
      primaryDns: 'dns.adguard-dns.com',
      isCustom: true,
    ),
    DnsServer(
      id: 'quad9',
      name: 'Quad9 DNS',
      primaryDns: 'dns.quad9.net',
      isCustom: true,
    ),
    DnsServer(
      id: 'mullvad',
      name: 'Mullvad DNS',
      primaryDns: 'base.dns.mullvad.net',
      isCustom: true,
    ),
    DnsServer(
      id: 'controld',
      name: 'Control D',
      primaryDns: 'p0.freedns.controld.com',
      isCustom: true,
    ),
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DnsServer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
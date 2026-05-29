class DnsLeakResult {
  final String clientIp;
  final String clientIsp;
  final String clientCountry;
  final String dnsIp;
  final String dnsGeo;
  final bool isLeak;

  DnsLeakResult({
    required this.clientIp,
    required this.clientIsp,
    required this.clientCountry,
    required this.dnsIp,
    required this.dnsGeo,
    required this.isLeak,
  });

  factory DnsLeakResult.fromJson({
    required Map<String, dynamic> clientJson,
    required Map<String, dynamic> dnsJson,
    required bool isProtectionRunning,
  }) {
    final clientIp = clientJson['query'] as String? ?? 'Unknown';
    final clientIsp = clientJson['isp'] as String? ?? 'Unknown';
    final clientCountry = clientJson['country'] as String? ?? 'Unknown';

    final dnsData = dnsJson['dns'] as Map<String, dynamic>?;
    final dnsIp = dnsData?['ip'] as String? ?? 'Unknown';
    final dnsGeo = dnsData?['geo'] as String? ?? 'Unknown';

    // A leak is suspected if:
    // 1. Protection is running
    // 2. The DNS resolver's ISP is the same as the client's ISP (or the DNS resolver IP matches the client IP)
    // 3. Or if the DNS geo location mentions the client's ISP name
    bool isLeak = false;
    if (isProtectionRunning) {
      final clientIspLower = clientIsp.toLowerCase();
      final dnsGeoLower = dnsGeo.toLowerCase();
      
      // If the DNS resolver geo matches the client's ISP or client's IP is same as DNS resolver IP
      if (clientIp == dnsIp || 
          dnsGeoLower.contains(clientIspLower) || 
          clientIspLower.contains(dnsGeoLower)) {
        isLeak = true;
      }
    }

    return DnsLeakResult(
      clientIp: clientIp,
      clientIsp: clientIsp,
      clientCountry: clientCountry,
      dnsIp: dnsIp,
      dnsGeo: dnsGeo,
      isLeak: isLeak,
    );
  }
}

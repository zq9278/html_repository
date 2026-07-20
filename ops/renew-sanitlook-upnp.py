#!/usr/bin/env python3
import socket
import subprocess
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from urllib.error import HTTPError

INTERNAL_CLIENT = "192.168.3.181"
PORT_MIN = 18080
PORT_MAX = 18120

DESCRIPTIONS = {
    18080: "snd-site",
    18081: "www-sanitlook-site",
    18082: "snd100-linuokang-site",
    18083: "snd100-dashboard-app",
    18084: "feiniu-monitor-site",
}


def active_ports():
    output = subprocess.check_output(["ss", "-tln"], text=True, errors="replace")
    ports = set()
    for line in output.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        local = parts[3]
        if ":" not in local:
            continue
        try:
            port = int(local.rsplit(":", 1)[1])
        except ValueError:
            continue
        if PORT_MIN <= port <= PORT_MAX:
            ports.add(port)
    return sorted(ports)


def discover_gateway():
    request = "\r\n".join(
        [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            'MAN: "ssdp:discover"',
            "MX: 2",
            "ST: urn:schemas-upnp-org:device:InternetGatewayDevice:1",
            "",
            "",
        ]
    ).encode()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.settimeout(4)
    sock.sendto(request, ("239.255.255.250", 1900))

    deadline = time.time() + 4
    while time.time() < deadline:
        data, _ = sock.recvfrom(8192)
        for line in data.decode(errors="ignore").splitlines():
            if line.lower().startswith("location:"):
                return line.split(":", 1)[1].strip()
    raise RuntimeError("No UPnP InternetGatewayDevice found")


def get_wan_service(description_url):
    document = urllib.request.urlopen(description_url, timeout=8).read()
    root = ET.fromstring(document)
    for node in root.iter():
        if not node.tag.endswith("service"):
            continue
        service = {child.tag.split("}", 1)[-1]: child.text or "" for child in node}
        service_type = service.get("serviceType", "")
        if "WANIPConnection" in service_type or "WANPPPConnection" in service_type:
            base = urllib.parse.urljoin(description_url, "/")
            control_url = urllib.parse.urljoin(base, service["controlURL"])
            return control_url, service_type
    raise RuntimeError("No WAN connection service found")


def soap(control_url, service_type, action, body):
    envelope = f"""<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:{action} xmlns:u="{service_type}">
{body}
    </u:{action}>
  </s:Body>
</s:Envelope>""".encode()
    request = urllib.request.Request(
        control_url,
        data=envelope,
        method="POST",
        headers={
            "Content-Type": 'text/xml; charset="utf-8"',
            "SOAPAction": f'"{service_type}#{action}"',
        },
    )
    try:
        response = urllib.request.urlopen(request, timeout=10)
        return response.status, response.read().decode(errors="replace")
    except HTTPError as error:
        return error.code, error.read().decode(errors="replace")


def delete_mapping(control_url, service_type, port):
    body = f"""      <NewRemoteHost></NewRemoteHost>
      <NewExternalPort>{port}</NewExternalPort>
      <NewProtocol>TCP</NewProtocol>"""
    status, payload = soap(control_url, service_type, "DeletePortMapping", body)
    if status == 500 and "<errorCode>714</errorCode>" in payload:
        return
    if status not in (200, 714):
        raise RuntimeError(f"DeletePortMapping {port} failed: HTTP {status}: {payload[:300]}")


def add_mapping(control_url, service_type, port):
    description = DESCRIPTIONS.get(port, f"sanitlook-site-{port}")
    body = f"""      <NewRemoteHost></NewRemoteHost>
      <NewExternalPort>{port}</NewExternalPort>
      <NewProtocol>TCP</NewProtocol>
      <NewInternalPort>{port}</NewInternalPort>
      <NewInternalClient>{INTERNAL_CLIENT}</NewInternalClient>
      <NewEnabled>1</NewEnabled>
      <NewPortMappingDescription>{description}</NewPortMappingDescription>
      <NewLeaseDuration>0</NewLeaseDuration>"""
    status, payload = soap(control_url, service_type, "AddPortMapping", body)
    if status != 200:
        raise RuntimeError(f"AddPortMapping {port} failed: HTTP {status}: {payload[:300]}")
    print(f"{port} -> {INTERNAL_CLIENT}:{port} ({description})")


def main():
    ports = active_ports()
    if not ports:
        print(f"No active ports in {PORT_MIN}-{PORT_MAX}")
        return
    control_url, service_type = get_wan_service(discover_gateway())
    for port in ports:
        delete_mapping(control_url, service_type, port)
        add_mapping(control_url, service_type, port)


if __name__ == "__main__":
    main()

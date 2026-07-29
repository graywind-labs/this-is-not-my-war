import { execFileSync, spawn } from 'node:child_process';
import net from 'node:net';
import path from 'node:path';

const PROXY_PATH = path.join(process.env.USERPROFILE, '.codex', 'scripts', 'godot-mcp-proxy.mjs');
const BROKER_PORT = 8765;
const GODOT_PORT = 6550;
const TCP_LISTEN = 2;
const TCP_ESTABLISHED = 5;

function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function requestBroker(payload) {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: '127.0.0.1', port: BROKER_PORT }, () => {
      socket.write(`${JSON.stringify(payload)}\n`);
    });
    socket.setEncoding('utf8');
    let buffer = '';
    socket.on('data', (chunk) => {
      buffer += chunk;
      if (!buffer.includes('\n')) {
        return;
      }
      socket.end();
      resolve(JSON.parse(buffer.slice(0, buffer.indexOf('\n'))));
    });
    socket.on('error', reject);
  });
}

function powershellJson(command) {
  const output = execFileSync(
    'powershell.exe',
    ['-NoProfile', '-Command', `${command} | ConvertTo-Json -Compress`],
    { encoding: 'utf8', windowsHide: true }
  ).trim();
  if (!output) {
    return [];
  }
  const parsed = JSON.parse(output);
  return Array.isArray(parsed) ? parsed : [parsed];
}

function getTopology() {
  const processes = powershellJson(
    "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'node.exe' -and $_.CommandLine -match 'godot-mcp-(proxy|broker)\\.mjs' } | Select-Object ProcessId,ParentProcessId,CommandLine"
  );
  const connections = powershellJson(
    `Get-NetTCPConnection -LocalPort ${BROKER_PORT},${GODOT_PORT} -ErrorAction SilentlyContinue | Select-Object LocalPort,RemotePort,State,OwningProcess`
  );
  return {
    proxies: processes.filter((processInfo) => String(processInfo.CommandLine).includes('godot-mcp-proxy.mjs')),
    brokers: processes.filter((processInfo) => String(processInfo.CommandLine).includes('godot-mcp-broker.mjs')),
    brokerListeners: connections.filter((connection) => Number(connection.LocalPort) === BROKER_PORT && Number(connection.State) === TCP_LISTEN),
    godotEstablished: connections.filter((connection) => Number(connection.LocalPort) === GODOT_PORT && Number(connection.State) === TCP_ESTABLISHED)
  };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function waitForStableTopology(timeoutMilliseconds = 10000) {
  const deadline = Date.now() + timeoutMilliseconds;
  let topology = getTopology();

  while (
    Date.now() < deadline &&
    (
      topology.brokers.length !== 1 ||
      topology.brokerListeners.length !== 1 ||
      topology.godotEstablished.length !== 1
    )
  ) {
    await sleep(250);
    topology = getTopology();
  }

  return topology;
}

const proxies = [
  spawn(process.execPath, [PROXY_PATH], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true }),
  spawn(process.execPath, [PROXY_PATH], { stdio: ['pipe', 'pipe', 'pipe'], windowsHide: true })
];
const proxyStderr = ['', ''];
for (const [index, proxy] of proxies.entries()) {
  proxy.stderr.setEncoding('utf8');
  proxy.stderr.on('data', (chunk) => {
    proxyStderr[index] += chunk;
  });
}

function proxyStatus(index) {
  const proxy = proxies[index];
  return `exitCode=${proxy.exitCode}, signalCode=${proxy.signalCode}, stderr=${JSON.stringify(proxyStderr[index])}`;
}

try {
  let topology = await waitForStableTopology();
  assert(proxies.every((proxy) => proxy.exitCode === null), 'Both session-local proxies must remain alive.');
  assert(topology.proxies.length >= 2, `Expected at least two proxies, found ${topology.proxies.length}.`);
  assert(topology.brokers.length === 1, `Expected one broker, found ${topology.brokers.length}.`);
  assert(topology.brokerListeners.length === 1, `Expected one broker listener, found ${topology.brokerListeners.length}.`);
  assert(topology.godotEstablished.length === 1, `Expected one Godot connection, found ${topology.godotEstablished.length}.`);

  const health = await requestBroker({ id: 'topology-health', op: 'health' });
  assert(health.ok, `Broker health failed: ${JSON.stringify(health)}`);
  const tools = await requestBroker({ id: 'topology-tools', op: 'listTools' });
  assert(tools.ok && Array.isArray(tools.result) && tools.result.length > 0, 'Broker listTools failed.');

  proxies[0].stdin.end();
  await sleep(1000);
  topology = getTopology();
  assert(
    proxies[1].exitCode === null,
    `Closing one session proxy must not close the other proxy (${proxyStatus(1)}).`
  );
  assert(topology.brokers.length === 1 && topology.godotEstablished.length === 1, 'Closing one proxy must not disrupt broker-to-Godot.');

  console.log('Godot MCP multi-session topology verification passed.');
} finally {
  for (const proxy of proxies) {
    if (proxy.exitCode === null) {
      proxy.stdin.end();
      await sleep(200);
    }
    if (proxy.exitCode === null) {
      proxy.kill();
    }
  }
}

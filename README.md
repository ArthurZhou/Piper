# Piper
A message transfer protocol that uses all clients as relays

## How does this work
Piper is a client-as-server network, similar to p2p,
But all clients in the network are also relay servers.

This is similar to the IRC protocol. But Piper doesn't require a central server.
Instead, all messages are transferred from one client to another.
When a message is repeated multiple times (default 3 times). The relay server will stop repeating it any longer.

## Message structure
```json
{
  "operation": "msg",
  "msg": "",
  "name": "",
  "uuid": "",
  "jump": 0,
  "port": 0
}
```
`operation` tells relay servers what wo do with this message. 
Use `msg` when sending messages.

`msg` is the body of the message.

`name` and `uuid` include information of the sender. `uuid` is a random version 4 uuid.

`jump` shows how many times this message has been repeated.

`port` shows the port of the relay server which send this message to you.

## Command line arguments
Use `Piper --help` to print help message

```
Usage: Piper [options] [ARGS]                                              
                                                                           
Options:                                                                   
  -s, --server <string>     Remote server address  split addresses with `;`
  -h, --host <int>          Local server port  default: 28174
  -n, --name <string>       Username  default: user-0
  -u, --uuid <string>       UUID(You should not change this by default)  default: <random v4 uuid>
```
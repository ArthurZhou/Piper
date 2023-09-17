module main

import net
import os
import flag
import rand
import log
import time
import json

__global (
	remote_addr []string // connect to target at launch
	host_port   int // the port of local relay server
	my_name     string // username
	my_uuid     string // uuid(random by default)
	p           &log.Log // message output
	l           &log.Log // log output
	client_list map[string]Client // all connected clients(relays)
)

struct Context { // message transfer structure
	operation string // `msg`(transfer chat msg) or `reg`(add itself to a relay's client list)
	msg       string // body of msg, this section will be the port number of local relay server when operation is `reg`
	name      string // username
	uuid      string // uuid
mut:
	jump int // how many times has this message been repeated
	port int
}

struct Client { // structure used to save clients in a client list
	time_reg time.Time // registration time
	max_msg  int       // max message amount can be sent to this client(if reached this limit, the client will be removed from the list)
mut:
	current_msg int // how many messages have been sent to this client
}

fn send_msg(msg string) { // render and broadcast input msg to all clients
	if client_list.len > 0 {
		data := json.encode(Context{
			operation: 'msg'
			msg: msg
			name: my_name
			uuid: my_uuid
			jump: 0
			port: host_port
		})
		send(data, '') // set except to nothing to send the message to everyone
	}
}

fn send(msg string, except string) {
	for index, mut client in client_list {
		if client.current_msg <= client.max_msg || client.max_msg == -1 {
			if index != except { // send to all clients except someone, useful when repeating messages(except the client who sent me this message)
				l.debug('sending message to ${index}. ${client.current_msg}/${client.max_msg} message(s) already transferred.')
				mut s := net.dial_udp(index) or {
					l.warn(err.str())
					return
				}
				s.write_string(msg) or {
					l.warn(err.str())
					return
				}
				s.close() or { return }
				l.debug('done sending message to ${index}.')
			}
			client.current_msg += 1
		} else {
			l.debug('client ${index} reach the limit of ${client.max_msg} message(s). now removing from list.')
			client_list.delete(index)
		}
	}
}

fn receive_msg(addr string) {
	println(addr)
	mut server := net.listen_udp(addr) or {
		l.warn(err.str())
		return
	}
	for {
		mut buf := []u8{len: 1024}
		_, client_addr := server.read(mut buf) or {
			l.warn(err.str())
			return
		}
		mut data := json.decode(Context, buf.bytestr()) or {
			l.error('failed to decode message: ${buf.bytestr()}. from ${client_addr.str()}.')
			return
		}
		if data.operation == 'msg' {
			if client_list[client_addr.str()] == Client{} {
				client_list[client_addr.str().split(':')[0] + ':' + data.port.str()] = Client{
					time_reg: time.now()
					max_msg: 256
					current_msg: 0
				}
			}
			p.info('(${data.name}) > ${data.msg}')
			if data.jump < 3 {
				data.jump += 1
				data.port = host_port
				send(json.encode(data), client_addr.str())
			}
		} else if data.operation == 'relay' {
			mut relays := client_list.clone()
			relays.delete(client_addr.str())
			server.write_to(client_addr, json.encode(relays).bytes()) or {
				l.debug('failed to send available client list to ${client_addr}')
				return
			}
		} else {
			l.warn('unknown operation: ${data.operation} from ${client_addr.str()}')
		}
	}
}

fn get_relay(addr string) {
	mut s := net.dial_udp(addr) or {
		l.info(err.str())
		return
	}
	data := json.encode(Context{
		operation: 'relay'
	})
	s.write_string(data) or {
		l.info(err.str())
		return
	}
	mut buf := []u8{len: 1024}
	_, _ := s.read(mut buf) or {
		l.info(err.str())
		return
	}
	mut relays := json.decode(map[string]Client, buf.bytestr()) or {
		l.info('failed to decode relay list from ${addr}  detail: ${err.str()}')
		return
	}
	for key, mut relay in relays {
		if client_list[key] == Client{} {
			relay.current_msg = 0
			client_list[key] = relay
		}
	}
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Piper')
	fp.version('v0.1.2')

	remote_addr = ['127.0.0.1:28175']
	host_port = 28176
	my_name = 'user1'
	my_uuid = fp.string('uuid', `u`, rand.uuid_v4(), 'UUID(You should not change this by default)  default: <random v4 uuid>')
	if os.args.contains('--help') {
		println(fp.usage())
		exit(0)
	}

	l = &log.Log{}
	l.set_output_level(log.Level.debug)
	p = &log.Log{}
	p.set_output_level(log.Level.info)

	if remote_addr != [''] {
		for addr in remote_addr {
			client_list[addr] = Client{
				time_reg: time.now()
				max_msg: 256
				current_msg: 0
			}
		}
	}

	spawn receive_msg('127.0.0.1:' + host_port.str())

	for {
		line := os.input('')
		if line == '' || line == '\r\n' || line == '\n' {
			p.info('Exit? [Y/n]: ')
			sure := os.get_line()
			if sure == 'Y' || sure == 'Y\r\n' || sure == 'Y\n' {
				break
			}
		} else {
			send_msg(line)
		}
	}
}

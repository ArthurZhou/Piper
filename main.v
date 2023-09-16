module main

import net
import os
import flag
import rand
import log
import time
import json

__global (
	remote_addr    string
	host_port      int
	my_name        string
	my_uuid        string
	p              &log.Log
	l              &log.Log
	client_list    &[]Client
	connected_list &[]string
)

struct Context {
	operation string
	msg       string
	name      string
	uuid      string
mut:
	jump int
}

struct Client {
	addr     string
	time_reg time.Time
	max_err  int
mut:
	current_err int
}

fn send_msg(msg string) {
	if client_list.len > 0 {
		send(msg, '', false)
	}
}

fn send(msg string, except string, send_raw bool) {
	for mut client in client_list {
		mut index := 0
		if client.current_err <= client.max_err || client.max_err == -1 {
			if client.addr != except {
				l.debug('sending message to ${client.addr}.')
				mut s := net.dial_udp(client.addr) or {
					l.warn(err.str())
					return
				}

				if !send_raw {
					data := json.encode(Context{
						operation: 'msg'
						msg: msg
						name: my_name
						uuid: my_uuid
						jump: 0
					})
					s.write_string(data) or {
						l.warn(err.str())
						return
					}
				} else {
					s.write_string(msg) or {
						l.warn(err.str())
						return
					}
				}

				l.debug('done sending message to ${client.addr}.')
			}
		} else {
			l.debug('client ${client.addr} reach the limit of ${client.max_err} error(s). now removing from list.')
			client_list.delete(index)
		}
		index += 1
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
			p.info('(${data.name}) > ${data.msg}')
			if data.jump < 3 {
				data.jump += 1
				send(json.encode(data), client_addr.str(), true)
			}
		} else if data.operation == 'reg' {
			client_ip := client_addr.str().split(':')[0]
			client_list << Client{
				addr: client_ip + ':' + data.msg
				time_reg: time.now()
				max_err: 2
				current_err: 0
			}
		} else {
			l.warn('unknown operation: ${data.operation} from ${client_addr.str()}')
		}
	}
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Piper')
	fp.version('v0.1.0')

	remote_addr = fp.string('server', `s`, '', 'Remote server address')
	host_port = fp.int('host', `h`, 28174, 'Local server port  default: 28174')
	my_name = fp.string('name', `n`, 'user-0', 'Username  default: user-0')
	my_uuid = fp.string('uuid', `u`, rand.uuid_v4(), 'UUID(You should not change this by default)  default: <random v4 uuid>')
	if os.args.contains('--help') {
		println(fp.usage())
		exit(0)
	}

	l = &log.Log{}
	l.set_output_level(log.Level.debug)
	p = &log.Log{}
	p.set_output_level(log.Level.info)

	client_list = &[]Client{}
	if remote_addr != '' {
		client_list << Client{
			addr: remote_addr
			time_reg: time.now()
			max_err: -1
			current_err: 0
		}
		mut s := net.dial_udp(remote_addr) or {
			l.warn(err.str())
			return
		}
		data := json.encode(Context{
			operation: 'reg'
			msg: host_port.str()
			name: my_name
			uuid: my_uuid
		})
		s.write_string(data) or {
			l.warn(err.str())
			return
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

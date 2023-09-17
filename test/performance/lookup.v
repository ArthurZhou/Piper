module main

import time
import rand
import os

struct Client { // structure used to save clients in a client list
	addr     string    // relay server address
	time_reg time.Time // registration time
	max_msg  int       // max message amount can be sent to this client(if reached this limit, the client will be removed from the list)
mut:
	current_msg int // how many messages have been sent to this client
}

fn walkthrough(clients map[string]Client, random string) {
	for _, client in clients {
		if client.current_msg <= client.max_msg || client.max_msg == -1 {
			if client.addr != random { // send to all clients except someone, useful when repeating messages(except the client who sent me this message)
				time.sleep(time.millisecond * 5)
			}
		}
	}
}

fn search(clients map[string]Client, loop int, max int) {
	mut loop_mut := loop
	for loop_mut >= 0 {
		client := clients[rand.int_in_range(0, max) or { panic(err) }.str()]
		client.addr
		client.current_msg
		client.max_msg
		loop_mut--
		time.sleep(rand.int_in_range(0, 500) or { panic(err) } * time.millisecond)
	}
}

fn main() {
	mut amount := 1000
	mut loop := 100
	random_txt := rand.uuid_v4()

	mut client_list := map[string]Client{}
	for amount >= 0 {
		addr := amount.str()
		client_list[addr] = Client{
			addr: addr
			time_reg: time.now()
			max_msg: 256
			current_msg: 0
		}
		amount--
	}
	println('ready')
	os.input('press any key to start walkthrough\n')
	time.sleep(time.second * 3)
	println('starting')
	walkthrough(client_list, random_txt)
	os.input('press any key to start search\n')
	time.sleep(time.second * 3)
	println('starting')
	search(client_list, loop, amount)
}

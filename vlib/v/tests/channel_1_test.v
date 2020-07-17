import sync

const (
	num_iterations = 1000000
)

fn do_send(mut ch sync.Channel) {
	for i in 0 .. num_iterations {
		ch.push(&i)
	}
}

fn test_channel_buffered() {
	mut ch := sync.new_channel(1000, sizeof(int))
	go do_send(mut ch)
	mut sum := i64(0)
	for _ in 0 .. num_iterations {
		a := 0
		ch.pop(&a)
		sum += a
	}
	assert sum == u64(num_iterations)*(num_iterations-1)/2
}

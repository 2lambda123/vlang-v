import time
import math
import sokol.audio

const (
	sw          = time.new_stopwatch({})
	sw_start_ms = sw.elapsed().milliseconds()
)

[inline]
fn sintone(periods, frame, num_frames int) f32 {
	return math.sinf(f32(periods) * (2 * math.pi) * f32(frame) / f32(num_frames))
}

fn my_audio_stream_callback(buffer &f32, num_frames, num_channels int) {
	ms := sw.elapsed().milliseconds() - sw_start_ms
	unsafe {
		mut soundbuffer := buffer
		for frame := 0; frame < num_frames; frame++ {
			for ch := 0; ch < num_channels; ch++ {
				idx := frame * num_channels + ch
				if ms < 500 {
					soundbuffer[idx] = sintone(20, frame, num_frames)
				} else if ms < 1000 {
					soundbuffer[idx] = sintone(25, frame, num_frames)
				} else if ms < 1500 {
					soundbuffer[idx] *= sintone(22, frame, num_frames)
				} else {
					soundbuffer[idx] = sintone(25, frame, num_frames)
				}
			}
		}
	}
}

fn main() {
	audio.setup({
		stream_cb: my_audio_stream_callback
	})
	time.sleep_ms(2500)
	audio.shutdown()
}

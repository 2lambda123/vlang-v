import time
import gg
import glfw
import gx
import automaton

const (
	screenWidth = 800
	screenHeight = 600
	filled_color = gx.Blue
)

fn new_graphics() &gg.GG {
	glfw.init_glfw()
	return gg.new_context(gg.Cfg{
		width: screenWidth
		height: screenHeight
		use_ortho: true
		create_window: true
		resizable: false
		window_title: 'v life (with gg, glfw, gx)'
	})
}

const (
	graphics = new_graphics()
)

[live]
fn print_automaton(a &automaton.Automaton){
	gg.clear(gx.White)
	square_size := 18
	for i, line in a.field {
		for j, cell in line {
			if j == 0 || j == line.len - 1 { continue }
			if cell == 1 {
				graphics.draw_rect( square_size*j, square_size*i, square_size, square_size, filled_color )
			}
		}
	}
}

fn main() {
	mut a := automaton.gun()
	for {
		if graphics.window.should_close() { graphics.window.destroy() break }
		gg.post_empty_event() // needed so the animation does not stop
		///////////////////////////////////////////////
		a.update()
		print_automaton(a)
		
		graphics.render()
		time.sleep_ms(1) // TODO: remove this when live reload depence on the time module is fixed
	}
}

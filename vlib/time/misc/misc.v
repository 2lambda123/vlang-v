module misc

import rand
import time

const start_time_unix = time.now().unix_time()

// random returns a random time struct in *the past*.
pub fn random() time.Time {
	return time.unix(int(rand.i64n(misc.start_time_unix) or { 0 }))
}

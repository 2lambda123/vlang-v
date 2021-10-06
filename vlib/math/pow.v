module math

const (
	pow10tab      = [f64(1e+00), 1e+01, 1e+02, 1e+03, 1e+04, 1e+05, 1e+06, 1e+07, 1e+08, 1e+09,
		1e+10, 1e+11, 1e+12, 1e+13, 1e+14, 1e+15, 1e+16, 1e+17, 1e+18, 1e+19, 1e+20, 1e+21, 1e+22,
		1e+23, 1e+24, 1e+25, 1e+26, 1e+27, 1e+28, 1e+29, 1e+30, 1e+31]
	pow10postab32 = [f64(1e+00), 1e+32, 1e+64, 1e+96, 1e+128, 1e+160, 1e+192, 1e+224, 1e+256, 1e+288]
	pow10negtab32 = [f64(1e-00), 1e-32, 1e-64, 1e-96, 1e-128, 1e-160, 1e-192, 1e-224, 1e-256, 1e-288,
		1e-320]
)

// powf returns base raised to the provided power. (float32)
[inline]
pub fn powf(a f32, b f32) f32 {
	return f32(pow(a, b))
}

// pow10 returns 10**n, the base-10 exponential of n.
//
// special cases are:
// pow10(n) =    0 for n < -323
// pow10(n) = +inf for n > 308
pub fn pow10(n int) f64 {
	if 0 <= n && n <= 308 {
		return math.pow10postab32[u32(n) / 32] * math.pow10tab[u32(n) % 32]
	}
	if -323 <= n && n <= 0 {
		return math.pow10negtab32[u32(-n) / 32] / math.pow10tab[u32(-n) % 32]
	}
	// n < -323 || 308 < n
	if n > 0 {
		return inf(1)
	}
	// n < -323
	return 0.0
}

// powi returns base raised to power (a**b) as an integer (i64)
// 
// special case:
// powi(a, b) = -1 for a = 0 and b < 0
pub fn powi(a i64, b i64) i64 {
	mut b_ := b
	mut p := a
	mut v := i64(1)

	if b_ < 0 { // exponent < 0
		if a == 0 {
			return -1 // division by 0
		}
		return if a * a != 1 {
			0
		} else {
			if (b_ & 1) > 0 {
				a
			} else {
				1
			}
		}
	}

	for ; b_ > 0; {
		if b_ & 1 > 0 {
			v *= p
		}
		p *= p
		b_ >>= 1
	}

	return v
}

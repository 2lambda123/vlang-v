type ParseRes = Result<[]Token, ParseErr>

struct ParseErr {}

type Opt<T> = None<T> | Some<T>

struct None<T> {}

struct Some<T> {
	value T
}

type Result<T, U> = Err<U> | Ok<T>

struct Ok<T> {
	value T
}

struct Err<U> {
	value U
}

fn test_report() {
	r := Opt<ParseRes>(None<ParseRes>{})
	match r {
		Some<ParseRes> {
			// make possible cast fo the same type!
			rx := Result<[]Token, ParseErr>(r.value)
		}
		None<ParseRes> {}
	}
}

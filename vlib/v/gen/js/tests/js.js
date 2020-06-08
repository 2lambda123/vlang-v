// V_COMMIT_HASH 808975f
// V_CURRENT_COMMIT_HASH 564545d
// Generated by the V compiler

"use strict";

/** @namespace builtin */
const builtin = (function () {
	/**
	 * @function
	 * @param {any} s
	 * @returns {void}
	*/
	function println(s) {
		console.log(s);
	}
	
	/**
	 * @function
	 * @param {any} s
	 * @returns {void}
	*/
	function print(s) {
		process.stdout.write(s);
	}

	/* module exports */
	return {
		println,
		print
	};
})();

/** @namespace hello */
const hello = (function () {
	/**
	 * @function
	 * @returns {void}
	*/
	function raw_js_log() {
		console.log('hello')
	}
	
	/** @constant {string} */
	const hello = "Hello";
	
	/**
	 * @constructor
	 * @param {{foo?: string}} init
	*/
	function Aaa({ foo = "" }) {
		this.foo = foo
	};
	Aaa.prototype = {
		/** @type {string} */
		foo: "",
		/**
		 * @function
		 * @param {string} s
		 * @returns {void}
		*/
		update(s) {
			const a = this;
			a.foo = s;
		}
	};

	
	/**
	 * @constructor
	 * @param {{}} init
	*/
	function Bbb({  }) {
	};
	Bbb.prototype = {
	};

	/** @enum {number} */
	const Ccc = {
		a: 0,
		b: 5,
		c: 6,
	};
	
	/**
	 * @function
	 * @returns {string}
	*/
	function v_debugger() {
		/** @type {Bbb} */
		const v = new Bbb({});
		return hello;
	}
	
	/**
	 * @function
	 * @returns {string}
	*/
	function excited() {
		return v_debugger() + "!";
	}

	/* module exports */
	return {
		raw_js_log,
		Aaa,
		Ccc,
		v_debugger,
		excited
	};
})();

/** @namespace main */
const main = (function (hl) {
	/** @constant {number} */
	const i_am_a_const = 21214;
	/** @constant {string} */
	const v_super = "amazing keyword";
	
	/**
	 * @constructor
	 * @param {{a?: hl["Aaa"]["prototype"]}} init
	*/
	function Foo({ a = new hl.Aaa({}) }) {
		this.a = a
	};
	Foo.prototype = {
		/** @type {hl["Aaa"]["prototype"]} */
		a: new hl.Aaa({})
	};

	/**
	 * @constructor
	 * @param {{google?: number, amazon?: boolean, yahoo?: string}} init
	*/
	function Companies({ google = 0, amazon = false, yahoo = "" }) {
		this.google = google
		this.amazon = amazon
		this.yahoo = yahoo
	};
	Companies.prototype = {
		/** @type {number} */
		google: 0,
		/** @type {boolean} */
		amazon: false,
		/** @type {string} */
		yahoo: "",
		/**
		 * @function
		 * @returns {number}
		*/
		method() {
			const it = this;
			/** @type {Companies} */
			const ss = new Companies({
				google: 2,
				amazon: true,
				yahoo: "hello"
			});
			const [a, b] = hello(2, "google", "not google");
			/** @type {string} */
			const glue = (a > 2 ? "more_glue" : a > 5 ? "more glueee" : "less glue");
			if (a !== 2) {
			}
			
			return 0;
		}
	};

	/** @enum {number} */
	const POSITION = {
		go_back: 0,
		dont_go_back: 1,
	};
	
	/**
	 * @function
	 * @param {string} v_extends
	 * @param {number} v_instanceof
	 * @returns {void}
	*/
	function v_class(v_extends, v_instanceof) {
		/** @type {number} */
		const v_delete = v_instanceof;
		const _tmp1 = v_delete;
	}
	
	/* program entry point */
	(async function() {
		builtin.println("Hello from V.js!");
		builtin.println(Math.atan2(1, 0));
		/** @type {number} */
		let a = 1;
		a *= 2;
		a += 3;
		builtin.println(a);
		/** @type {hl["Aaa"]["prototype"]} */
		let b = new hl.Aaa({});
		b.update("an update");
		builtin.println(b);
		/** @type {Foo} */
		let c = new Foo({
			a: new hl.Aaa({})
		});
		c.a.update("another update");
		builtin.println(c);
		const _tmp2 = "done";
		{
			const _tmp3 = "block";
		}
		
		const _tmp4 = POSITION.go_back;
		const _tmp5 = hl.Ccc.a;
		/** @type {string} */
		const v_debugger = "JS keywords";
		/** @type {string} */
		const v_await = v_super + ": " + v_debugger;
		/** @type {string} */
		let v_finally = "implemented";
		console.log(v_await, v_finally);
		/** @type {number} */
		const dun = i_am_a_const * 20;
		/** @type {string} */
		const dunn = hl.hello;
		for (let i = 0; i < 10; i++) {
		}
		
		for (let i = 0; i < "hello".length; ++i) {
			let x = "hello"[i];
		}
		
		for (let x = 1; x < 10; ++x) {
		}
		
		/** @type {number[]} */
		const arr = [1, 2, 3, 4, 5];
		for (let _tmp6 = 0; _tmp6 < arr.length; ++_tmp6) {
			let i = arr[_tmp6];
		}
		
		/** @type {Map<string, string>} */
		const ma = new Map([
			["str", "done"],
			["ddo", "baba"]
		]);
		for (let [m, n] of ma) {
			/** @type {string} */
			const iss = m;
		}
		
		await new Promise(function(resolve){
			async(0, "hello");
			resolve();
		});
		
		/** @type {(number: number) => void} */
		const fn_in_var = function (number) {
			builtin.println(tos3(`number: ${number}`));
		};
		hl.v_debugger();
		anon_consumer(hl.excited(), function (message) {
			builtin.println(message);
		});
		hl.raw_js_log();
	})();
	
	/**
	 * @function
	 * @param {string} greeting
	 * @param {(message: string) => void} anon
	 * @returns {void}
	*/
	function anon_consumer(greeting, anon) {
		anon(greeting);
	}
	
	/**
	 * @function
	 * @param {number} num
	 * @param {string} def
	 * @returns {void}
	*/
	function async(num, def) {
	}
	
	/* [inline] */
	/* [deprecated] */
	/**
	 * @function
	 * @deprecated
	 * @param {number} game_on
	 * @param {...string} dummy
	 * @returns {[number, number]}
	*/
	function hello(game_on, ...dummy) {
		for (let _tmp7 = 0; _tmp7 < dummy.length; ++_tmp7) {
			let dd = dummy[_tmp7];
			/** @type {string} */
			const l = dd;
		}
		
		(function defer() {
			/** @type {string} */
			const v_do = "not";
		})();
		return [game_on + 2, 221];
	}

	/* module exports */
	return {};
})(hello);



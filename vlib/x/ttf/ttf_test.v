/**********************************************************************
*
* BMP render module utility functions
*
* Copyright (c) 2021 Dario Deledda. All rights reserved.
* Use of this source code is governed by an MIT license
* that can be found in the LICENSE file.
*
* Note:
*
* TODO: 
* - manage text directions R to L
**********************************************************************/
import x.ttf
import os

const (
	font_path = "Qarmic_sans_Abridged.ttf"
	create_data = false  // use true to generate binary data for this test file
)

fn main() {
	mut tf := ttf.TTF_File{}
	if create_data == true {
		tf.buf = os.read_bytes(font_path) or { panic(err) }
		println("TrueTypeFont file [$font_path] len: ${tf.buf.len}")
	} else {
		tf.buf = get_raw_data(font_bytes)
	}
	tf.init()
	//println("Unit per EM: $tf.units_per_em")

	w  := 64
	h  := 32
	bp := 4
	sz := w * h* bp

	font_size  := 20
	device_dpi := 72
	scale      := f32(font_size * device_dpi) / f32(72 * tf.units_per_em)

	mut bmp := ttf.BitMap{
		tf       : &tf
		buf      : malloc(sz)
		buf_size : sz
		scale    : scale
		width    : w
		height   : h
	}

	y_base := int((tf.y_max - tf.y_min) * bmp.scale)
	bmp.clear()
	bmp.set_pos(0,y_base)
	bmp.init_filler()
	bmp.draw_text("Test Text")

	mut test_buf := get_raw_data(test_data)
	if create_data == true {
		bmp.save_as_ppm("test_ttf.ppm")
		bmp.save_raw_data("test_ttf.bin")
		test_buf = os.read_bytes("test_ttf.bin") or { panic(err) }
	}
	
	ram_buf := bmp.get_raw_bytes()
	assert ram_buf.len == test_buf.len 
	for i in 0..ram_buf.len {
		if test_buf[i] != ram_buf[i] {
			assert false
		}
	}
}

fn get_raw_data(data string) []byte{
	mut buf := []byte{}
	mut c := 0
	mut b := 0
	for ch in data {
		if ch >= `0` && ch <= `9` {
			b = b << 4
			b += int(ch - `0`)
			c++
		} else if ch >= `a` && ch <= `f` {
			b = b << 4
			b += int(ch - `a` + 10)
			c++
		}
		
		if c == 2 {
			buf << byte(b)
			b = 0
			c = 0
		}
	}
	return buf
}

const(
	test_data ="
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
00bf bfbf bfbf bfbf bfbf bfbf bf00 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
00bf bfbf bfbf bfbf bfbf bfbf bf00 0000
bfff ffff ffff ffff ffff ffff ffbf 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
bfff ffff ffff ffff ffff ffff ffbf 0000
00bf ffff ffbf ffff bfff ffff bf00 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
00bf ffff ffbf ffff bfff ffff bf00 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 00bf
ffbf 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 00bf
ffbf 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 bfbf
ffbf bfbf bf00 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0032 72bf
bfbf 0000 0000 bfbf bfbf 5400 00bf ffff
ffff ffff ffbf 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0000 0032 72bf
0000 0000 00bf ffff bf00 0065 9999 ffff
ffff bf00 00bf ffff ffff ff7f 0000 bfff
bfff bfff bf00 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 0065 9999 6500
0000 0000 00bf ffff bf00 bfff ffff ffbf
ffff ffbf bfff bfff bfbf ffff bf00 bfff
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 bf72 3300 7fbf
0000 0000 00bf ffff bf7f 5fff ffbf 3f7f
8fbf ffbf ffbf 5500 0000 5fbf 0000 bfff
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf7f 5fff ffbf 3f7f
0000 0000 00bf ffff bfbf ffbf bfbf ffff
ffff ffbf ffff ff7f 0000 0000 0000 bfff
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfbf 00bf bfbf 8f5f
0000 0000 00bf ffff 7f5f ffff ffff ffff
ffff ffbf 5fbf ffff bfbf bfbf 0000 bfff
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff 7f5f 0000 0000 0000
0000 0000 00bf ffff bfff bfff ffbf ffff
ffff ffbf 0000 5fbf ffff ffff bf00 bfff
bf00 0000 0000 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfff bfff ffbf ffff
0000 0000 00bf ffff bfff bf00 0000 0000
0000 0000 0000 0000 7f7f ffff bf00 bfff
bf00 0000 bf00 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfff bf00 0000 0000
0000 0000 00bf ffff bfff bf00 0000 0000
0000 bf00 bf00 0000 0055 bfff ffbf bfff
ff7f 00bf ff5f 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfff bf00 0000 0000
0000 0000 00bf ffff bfbf ffbf 0000 0055
7fbf ffbf ffbf 7f55 00bf ffff bf00 7f5f
ff7f 7f5f ffbf 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfbf ffbf 0000 0055
0000 0000 00bf ffff bfbf ffff bfbf bfff
ffff bfbf ffff ffff ffff ffff bf00 00bf
ffff ffff ffbf 0000 0000 0000 0000 0000
0000 0000 00bf ffff bfbf 0000 bfbf bf7f
0000 0000 00bf ffff bf00 bfff ffff ffff
ffbf 0000 bfbf ffff ffff bfbf 0000 00bf
ffbf ffff bf00 0000 0000 0000 0000 0000
0000 0000 00bf ffff bf00 bf00 0000 3f7f
0000 0000 0000 5fbf 0000 00bf ffbf 8f5f
3f00 0000 0000 5fbf bf5f 0000 0000 0000
0000 bf5f 0000 0000 0000 0000 0000 0000
0000 0000 0000 5fbf 0000 00bf ffbf 8f5f
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
0000 0000 0000 0000 0000 0000 0000 0000
"

font_bytes = "
00010000000c0080000300404f532f324198b7900000014800000056636d61705338f9ae00000360000002a467617370ffff000300003ef400000008676c796695f3c823000006e800002f6c68656164f1648806000000cc0000003668686561114c06c90000010400000024686d747803081c4d000001a0000001c06b65726ee34ae31a00003654000002226c6f6361a1ec967600000604000000e26d617870007b009a00000128000000206e616d65867c317d000038780000055e706f7374210ab64f00003dd80000011a000100000001000017617a595f0f3cf5000b080000000000c4100e6900000000c61e2ebffeb5fdbd09630826000000060001000000000000000100000931fdbd00000962feb5ff390963000100000000000000000000000000000070000100000070006800050031000300000000000000000000000000000002000100010434019000050008059a05330000011b059a0533000003d100660212000002000500000000000000800000a75000004a0000000000000000484c20200040002022190747fde700cd0931024320000111410000000000040000640000000001fc0000037d000002b100ce02d70064050a004104f9004506bd0020070300920189006402aa007d02aa0051031d004c04ac00c00239009e0314001401ff009e033cfff70473000d047300a9047300280473002004730000047300350473000a0473001a047300110473002101ff009e01ff009e04ac00c904ac00c004ac00c9047300bc0644004006a50045068f00570612003c064a003405bd003804b20035070d001e06de001d02c60033069200510661fff905a000430926003d0706003d07a7001a0650003d07930024065c00270628002a05970001063f0016064c0002096200020568001205e9002105ce0031032000aa030b000f031a0050042b00000473ffa602aa004a0502003e0515004b044900390535003404c000390270ffc60502002704c00042027300520212feb50452003e023d00380796004604d400460551002d050a00450543002703280033044900450394001204a7003504220011066d00080422001c049e003203ca003203f60087023b009c042d003305c5000704000100032f001603f600570314003402a2003c0473002804730020040000d302c4009e04000158047300bd06ac001b0652001a06ac002000000003000000030000001c00010000000000a0000300010000001c000400840000001a00100003000a007a007e00a300a800aa00ad00b000b400b900be037e2219ffff00000020007e00a000a800aa00ac00af00b200b700bc037e2219ffffffe3ffe00000ffbaffb90000ffb6ffb5ffb3ffb1fca0de51000100000000001600000000001800000000000000000000000000000003005f0060006100640010000602040000000000fd000100000000000000000000000000000001000200000000000000020000000000000000000000000000000000000000000000000000000000000001000000000003000400050006000700080009000a000b000c000d000e000f0010001100120013001400150016001700180019001a001b001c001d001e001f0020002100220023002400250026002700280029002a002b002c002d002e002f0030003100320033003400350036003700380039003a003b003c003d003e003f0040004100420043004400450046004700480049004a004b004c004d004e004f0050005100520053005400550056005700580059005a005b005c005d000000000000005e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660060006100000000000000000000000000000069006200000000000000000000000000000000000000000000000000000000006300000000000000000000005f0064000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065000000000000006b00000056005600560056007c00a4013401da024a02a602be02ea031603580380039803b003c203e004120438047604c004fa0548058c05bc060a06480668068c06b406dc0704074007b207ea083c087208ae08de09080952098e09b009ea0a2c0a520a8a0ab60b040b3c0b980bda0c1c0c3a0c6e0c960ce00d1c0d480d760d980db60dd80dd80dee0e0c0e540e8e0ec00f000f3c0f700fbc0ff0101e1052108810aa10fa1130116a11a811ee121a1256129012c612f2133a137813ba13e4140e1418147414d014ee1500151215301556159415de15fa160e1636165c16c4172e17b60000000400640000039c059a00030007002400380000331121112521112117363736333216151406070e011514172326353412353426232207060713373633321f011615140f010623222f01263534640338fcfa02d4fd2caf1f1b353b5c702e403f48182023a3423a261f1a1e40390b090a0c38090a380e070b093d07059afa66320536ec1c0f1e5f5031635050682f265f61334c011c4b3942110f19fcff3a0a0b3c0b090b0b3e0e0a4709090a000200cefffe01d206c1000b001300000126350227363316171403140237321714072627013e650701017070050ade76830a7b7f0a0203195c03824c7b027c50fc7e5dfeeb0a7f8903017a0000020064050b0258074100090013000000170306072635033633041703060726350336330123090d0157570c14520185090d0157570c1452073d51fe8a6a01016f0175510451fe8a6a01016f0175510000020041fff804bb065c0009005a000001060706073637133637050726273637323732373637363316170607363736373633161706071633161706070607262726270607060716331617060706072627262302072635361307020726353413072627363732373637133637025b161b17164b5b5c0606fe5d6a46040e3d23681f26251622364508022f5061231622354508022e771d3d0e021c0c1d0f107328161d16157a223d0e021108271314762e755f52015f9a745e515b8346040e3d298d01015e05050437687e7565010201891b1b0c080c5150040201b29839046033e80202aa9339036132e20404503218120604030f016b85706203045026171f0705030efe2301034c4b014103fe2e01024c4b0133090b524f04030304018d16150000050045fec404a507560044004b0052005c0067000001363732171136371617111617161514070623222726271116171615020511060726271106072326271106072627112627263537363332171617112403371225113637161701363736353427010607061514170526272627111617363711262b0106071116171617022a1c1e453101474701663c6208111d2e4a2234913c6e0bfed0014747011421491919013d5101555ca41114154451394dfee5140218011501513d010140900e019ffe308303058b01403d5a0d0c262a39272e4003211e1214503a060f020209010942010143fed9223f694814122054271cfe69274986d4fecc5dfecd40010144011304030103feec40010144012f295a9fae170e96683502154101142b011e4c011a42010143f9e33f8a0909a34b02833c7a14126c28e910040101fdcf0703030904900e0406fe5b0201040a0000050020ffeb06760625000d0019002700330041000001171e0117140607272e01273e0103161f01363f01342627230601171e0117140607272e01273e0103161f01363f013426272306003732171407010607262736370101822e7de11ac0b822a1c80509ae280cc42bb32a0593631cb4040a2d7ee11ac1b821a1c80508ae280dc42ab42a0593631cb401963d271332fb524439320b073e04bd06250208bcbdb6c90d0511d3c195c6fe99d33a0612ac1b77990a18fda70108bdbdb6c90c0411d3c195c7fe98d3390712ac1c779909170394033d432afad1450909503d34053700030092fff706a0074a002100290031000024170607262f01060523240335120126353625330413060716133613343716150207010607161736373403040312053637020646140370502b2ac3fecf5bfdb415110189d01f01514c0132090abcfeec44226360159efcf6aa052f85693baefe9b0f160195efdeb2b54f6d01155f61bc1a1201ee520167012382f1f60e0cfed3c59baffe4d6f011876040486fea0fe051b0383823228888afdaadcfecafeb90501bf019a000000010064050b012c074100090000001703060726350336330123090d0157570c1452073d51fe8a6a01016f01755100000001007dfe7402890805001500000037161706070203101316170607222726270203121301a67c5309125cc00dc45b27014f5a303e32c1010ccb0801041565628ffed9fe17fe1dfe6aa67c73083e5583020a01db020601a300010051fe740262080a0015000012273437161712130203060706072227363712130203811a625b4df00101b446442e4459070a66da020ab5070e7f730a0aabfe5ffda6fe1efe35af4d35086b558a01bf01f801ce0150000001004c03e602e106f3002700000126353633321714073637161506071617060726271615060726273637060726273637262736371601641b1c30301d1874742c21abc807072c5088120940490901127b43450405c7bf1a013a5705d9844f47484790ae020d3f6c50535c330e08767e5b48030f5541837507063d43694a6e3e10010000000100c000c703f303ed0017000001331617060723150607263d01232627363b01353637161702c79b840d0782a206685caf8b040889ac015d600c02c9015d600cab89040886a906685c97810d0780000001009efef1016600e10009000024170306072635033633015d090d0157570c1452dd51fed06a01016f012f5100000000010014026302e4032e000900000017060705262736332502d80c0672fe267a04077801d2032d5d600c0106685c01000001009efffe01a201090007000036373217140726279f76830a7b7f0aff0a7f8903017a0001fff7ffe00338074f000d0000011617060701062326273437013602f54201061cfd801f3a400625028013074f05613c36f9be5504442c560643580002000dfff1046405ca000b00150000011704131702052724032712131205201327022504030238440192500622fddb43fe77360e0fad110111019e240534fed7feb43a05ca0337fdf288fd0e17036401ae850318fceefe674a02336b01b41215fde600000100a90000031305c1001200000017020306232627121106072627343f01363302fe150515095e571123e36648132fe48b5905b740fe08fcc443033e033d0151f90c073d4825ba8c00000000010028fff6044805b700200000010413140205253216171423262704072635362524110225040306232227371225025c019b35fafe7c010e91f5066f44d5fe696f67010183019218feedfeea3a0a5d5e010244019a05b72bfe62e5feb2e912306257190c11190a617efce7011f0109190afef8746a1f01832e000000010020fff7045705c50027000001041f010607041302052403363332121724370225060726353637363526270407140726273712250269011c3d0a088701150533fe16fe001a0e544262fb01492313fefd5e6c610bd0cb1186febd325e4c090149018f05c518ee3c9e7455feabfe5d2d04019847fefe140efb01140e070714545d1918c1720707c7460a14553201201500000000020000fff6046a05c80017001d000001321702033716170623271306232627370405263d01120017000336371202e480140323a460140b49c4051056540a09fee4fee3632502742bfe1809d4f82205c86bfe7bfe1f0b095e6c08ff0041075dd402350f882a012d02e3edfe00fee92d0201f10000010035fff2044605c1002c000001363732170e0107250607173e013716121d0102050722003536373217161736133702270e01072227123f011602528f7a5808018bd5fef956020d52c787e0be28fe9787d2fed9074a49356be9ff2f040fe971e85c8a142293216d05a5081452512c06058d6f0f0c370a06fedcba4dfe232d06010376410a59a6010a012c69010c0f0d3f04ae013aaa07100000000002000a0000046605b80019002300000117161706072e012706020736373304130702052403351037360315120533241310250402403cf7110c555a414194dc0e8bf22101d52a011ffe1efdb81296cb9d2201532601360afec3febb05b801207452060a24100efedf9aa8121ffe706bfe76560602554a0139ddfcfc6c37fedd0a4c010f010526250001001afffb044d05c000190000011617140700031506232235371225060727262734371617362403c47f0a3bfe4210125a69014e013a77e791e70866cc705e013905c00a533f28fec5fda6f07c85f00291fc2b0d0d14635c0d2104062d000000030011ffef046105d60015001d0027000001330413170607041315020527240335123726273712131617363726270602071605372413262507022d2a01233b01097b01161925fe1360fe4d2b10cd670a042d9205bde7111a8cfb8707010146340151061bfe9d5105d601feff2dd0553efeeb37fe111a0216016d3c01178a6698290133feb8ae0429c18c080cfd6af5c92a01320134d4110d00000000020021fffe045305c10013001e000001041302052726353424001327020524031037360316172013272e01230706020802262520fd3b4d4201a30128040f57fe6cfe972ab27d8410c2015c3406119b8c2ef605c127fd21fd53100213357501010401135ffea10a1701830138b272fda6d51401765948800b4600000002009efffe01a204870007000f0000363732171407262712373217140726279f76830a7b7f0a0176830a7b7f0aff0a7f8903017a04040a7f8903017a0000000002009eff0801a204870007001100001237321714072627121703060726350336339f76830a7b7f0adc090d0157570c1452047d0a7f8903017afcfd51fed06a01016f012f510000000100c900910407048400130000090116171407222701262736370136331615060701f601c14e02463c36fdd85b03035b0228363c46024e028bfed6274a431c2001561f63661f0156201c434a270000000200c001690412038b000900130000001706070526273633251217060721262736332504040e076cfd9b75050873025c6d0e076cfd9b75050873025c02385e620e01076b5d0101515f620d056b5e01000100c900910407048400130000012627343732170116170607010623263536370101194e02463c3602285b03035bfdd8363c46024e01c103b4274a431c20feaa1f66631ffeaa201c434a27012a0000000200bcffff03ca074f001900210000013704131005060f01062326353437363534270e010726273736123316170607262701cf7901740efeb4590a01156163bbf9e45554454c1b0422567b631b0475900107430c14fe9afef5e14081ba5711d7f8929e9daa090d5005065d2a6bfa021161910d198a000000020040001e061005a40008003d00000114173613273706080105262f01020520033512253215140717071217361302252304000f0112053637171617161706072627052403271200253704131701cc7ee6bd0404e1fed00416fefcad1716abfef8fee70b3b028c910f0f0209567e0456fef97efec9fe8907033a013af1776695982d090e548c87fe43fe3342050d01d7019b4f0193630c02649416050154c2610bfefcfdf8080ea982fed404012047021e2b4b1f1781cffeb80b38015001d60c10fe5cd860feb8190a050407160d3451071e0a080d01b961015301e00a021cfe0aa50000020045fffc0662074a0015001c00000104001311142322351121111407262711363716151203212600212000038101770167035d6efb7d67670104606adcbc045801fefffef3fefbfebc074a06fe13fe6afc9f646202fffd0d6c01026b05b86c010190014cfcd5ce0191fe6400000000020057fff0062f07650025002f0000133217362504001315020516151404212627263536331617202435342427211106072235113405220711212c01372600b749114e01010181023d110bfec3cdfe5ffe6b706d550265656e012a013efee3e4fe3b21515f01bfe00e017501a701180101fe2a07654d2b0301fe74fed031fee3b442d8c1bc07081f46590c026362674803fe2a500e6506bc4ee32cfc9d06f49dc401330001003cffeb05e50753001a000001320417060722262306000312003320363316171404052403120003b1da015101095846b7d0fafe6601010172ed0101c2525501fe8dff00fcd0060202180753bb6061019d01fe16febcfe9ffee9330f5a7033080d035501bc024500000000010034fff206110765001f0000250607223511343732173637040013100005272635363717240011020025220701000d5b646553114ef70195022911fdf7fe62fb550265e70143019401fe5cfe90d65450500e6506bc4e044d2b0301fe74fe62fe81fd5f02061f50540a051501f4014801280133012c0000010038fffe05910745001a000001161506072103211615060721112116150607212627112627343704ef5d0268fc4701035e670169fca9040164114efb82520128016a074509586603fc76016b5f07fea7095b570d117f05f410565409000000010035fffd04a8074c001600000116150607211121161506072113060726271126273437044b5d0268fcf002a05d015ffd65010669630128016a074c09586803fd9d0e5f6107fd216b010172061910565409000001001effeb071907530028000001132122273637211617140727110623262f0104072403120025320417060722262306000312003332058001fe9b6403025f02ae5302517c0f5a480f03feb7f6fcda06020218015bda015101095846b7d0fafe5c01010168f7f70181010d5d66030e61540501fdb64b04444e9b080d035501bc024505bb6061019d01fe16febcfe9ffee900000001001dfff506b70747002200000113363732171116150607110623262703211106232627112635363711363732171121058b01016d6b01510150016b6d0101fbc7016b6d015b0259016d6b010439036f034d8a018afc3510585907fe5085018501abfe5a81018101aa0855561303c88d018cfc3b00000000010033fffc028f074400170000132322353433213215142b01113332151423212235343b01f2536c71017a716c5c5c6c71fe86716c530671765d5d76fa5e765d5d760000010051fff6069f075b002100000105263536332134373217333215062b01161102000522242736373216332400131004bbfc347f067803a8666e01b1830a6f972702fe42fe87dafeaf01095846c2d00118013f0106100101696c7105766470e4fecffdeafe1505bb606101aa01018901b2012c0001fff9fff8064607530024000001000136371615140700010401161506072627002511142322273303262734370334333215011a02fe01641c585638fe7efc9802f201d64d045f3a2ffe4cfd61657101030149034c017165035e01540244530106493f61fd7dfeae70fec93f524e04071d01276dfea15d5d01ae15564f2504076a710000010043fffa05a8075000120000131615112025363716171407040d0126270336af6d027e010f4d545a047cfee0fe9afe67c405010307500170f9f2531f0c046363264c160309bc061d73000001003d000508f00743001b000000270025110607222711363704010025161711062326351104010607044209fe99fe47016d610d065d02b8013f013e02b85b080d6170fe49fe990956012c4904973dfa3f82018606456b082ffbef04112f086bf9bb86018205c13dfb6949050000000001003dfff706c80743001600001304011136371615110623262f01002511140722271136a003a301aa025b7e0863620901fe35fcf06b610d06074357fc47039160180179f99e690a57cd04bf6ffa3582018606456b00000002001affe4077f075a001300250000011617062322262722000312000520001310002d012635343736370400130200212400111200033dc1010a51316e6c77fed9020a01a7010f010c01c015fe35fee7fe56273caaed018402420123fdfafe62fe70fdf202016d0692227d3f5001fe7bfef5fe81fec005012c019401b3017109080b432524150809fe33fde8fe2cfe4c0101e801aa014001ef00000002003dfff2062507650013001d0000002901110607223511343732173625040013150601220711212436372600047afe69fe270d5c646554114e010101950229110bfc24e05401bb019df00101fe5c0222fe2e500e6506bc4e044d2b0301fe74fed031ff031b2cfca706ea9dc4013300020024fe3307a6075a0016002e0000252627363316171633320013020025200003100005372604051617060726272627060724000312002104001102000703c43303046851346120770127020afe59fef1fef4fe401501cb0119563e025301074d04114c5b57e99a88abfe68fddc012301fc019e0190020402fea783eb2144580237360186010a017f014005fed4fe6cfe4dfe8f08081ddcde3b424f0d0267d38716060901e2020d01d401b401fe18fe56feb6fe1b140000020027fff2063b07650019002200001332173625040013020501161514232627012111060722351134052207112120132600964c114e0101019502291101fe9c01711e705742fe8bfd390d546e0203e0540201023d0101fe6607654d2b0301fe74fed0fe6c90fe3f262c5c017001bffe2a500e6506bc4ef425fca7018dc4012c0000000001002affe3060b075c002100000104171617060722262504031600130205242726273637321716052437342403122503630170e5520110463fccfeb5fda8070104d90116fd89fe6ed8520106502b4ecc012601a30bfb2b011a031e075c029134535701a00b1ffe73f4fef9fe8cfe7d1411853e4466013f6a071dafe5f4019702541a0000010001fffc059107440010000001212235343321321514232103142322270261fe0c6c7104ae716cfe17026771010671765d5d76f9e85d5d00000000010016fffc0602075b001b000013363316170211120005323711363332151114072227060724000310630c6468014a01019a0170cc5e0d646a65621158edfe6bfdd71106df740279fd7dfed6fed8fecd015405cb6d6ff9624e044d490301018c019e014800000000010002fffe06430748001400000901363316150607010607232627012627343732170323023b2a5a610818fd85265f015f26fd85180857642a016405608410693735fa147603037605ec353769108400010002fffe096307480029000009010607232627012627343732170901363736373217363316171617090136331615060701060723262704b3fef5265f015f26fd85180857672a023901190a0d10420706070742100d0a011a02372a645b0818fd85265f015f2602d0fda77603037605ec3537691084faa002682018400c01010c401820fd9805608410693735fa147603037600010012fff40553074f001f0000090126273437321709013633161506070901161714072227090106232635363701f9fe401d0a53633701af01b83763530a1dfe3701c91d0a536337fe48fe513763530a1d03a202c83537691084fd5f02978410693735fd42fd4135376910840297fd5f8410693735000000010021ffff05c0074f0015000009012627343732170901363316150607011114072627027dfdcd1f0a645f3601d201db365f640a1ffdc26d6e01022304473537691084fc7603808410693735fbc3fe4d6a07076a00000000010031fffe05b9073f0017000008013521222736372516150200061505321706072126351001430383fbf97f0f0688047a800afc5adb03df7f0f0688fba48002b802b5fc676905010b87fe7afd17e77a0171680509870102000000000100aaff2102d0082600110000133433251615060721112516171407252235aa6c01506a025cfeec01145c026afeb06c07a183020b4e6702f87f0102684e0b028300000001000fff8e030707f9000d000012371617011615060726270126350f6c4f0c021a170b46481afde12607f702115ef8cb2a4458010542073241540000010050ff21027608260011000005142305263536370511212627343705321502766cfeb06a025c0114feec5c026a01506c5a83020b4e680201078102674e0b028300000001ffa6fedd04d8ff9000090000012126273633213215060476fb905e02025d04726102fedd015d555c56000001004a0523026b0613000e00000015060726252627363332171e0117026b013487fed53703073e344ba9622105822a2d08076c162a3d2a3b0f0b000002003efff904ca04930009002600002536243734250604071601130607262f010621240336002532172e01272206232635362437041201b0c0016c07fef3aafed8010603ad14075f550a06effe8bfea60301018c0100d24e0183b7cd8e4d49060115db0127d9b90c98807d0a06aa6e8d020cfdb5700a094063b3120139b60110142d5d770c6908604e700507fef5000002004bffef04ce07560009001c00000106000714333600372601363716171112210413020005222706232227035cc0fe9407d8ad013f1706fc4d03676101e5016b015a0d01fe74fec496581e565701039e02fe829ecd010131f0c9034473010280fc37015d12fe81fef8fe341426267100000000010039ffec041004880019000001041706072e01230e010712173e0237161706040724031200026c0164050258357d5883ee0214f48db82b474d0609feebddfe2f0b01011e04880b995305013701ffbffeb50601a56301046474f1050501fc011f016700020034fff904e80747000a0020000025360037273423060007160103363716171a01170607263527022124031200253201a6c0016c0a03d8adfec11c0602e506036f5a05053301075f691af9fe8bfea60301018c013c90b90c017e98567d01fecff0d30396028076020e6bfc91fd765b700a0972f9fe8512017f010801cc1400020039ffec048204930007001d000001342304071617201605262712053637363316170604052403120025041303b3d7feba5793660178cbfdc7bf6c090164a0884141530102feddfedcfe272701017e0123019d04034c881cd40802bc0c0a01feaa1302783d01604ece023801e00127015b0d0ffecc000001ffc60000029d0749001e0000011e011706072e01270607331617060723131407222703232235343f013e01018c87890108461e604a6404eb4d04084dea0b64600e0d2d555a31059407490148474a02011b020cce0b425a08fb79700b7c04855b4f0504ace80000020027fde404bf0468000a0028000025360037273423060007160801072e013536373216333e0137130221240312002532173633161713030199c0016c0a03d8adfec11c0603c4fed7e7c0a903564f6d5967de0203fcfe8bfea60301018c013c96581e5561010c09af0c017e98567d01fecff0d3fe82feb805014d5045143001c3e90112fe8512017f010801cc1426260170fdebfe58000001004200030466073d001b000037263502353637161713122504131403062326351235262722000306c5671c0d586007099e014f015d05140a6855100a9392fef43205070c6806174c5e01097afc5a016d070afe44f2fe986508630166dffd11fe83fe2a5e000000020052fff9023e06990007001800000116150607262736121703163332363332170607240313363301056913657202168d0109145d1c3322350a02bcfed7050b056206991a6c680c058f66fde56dfd8fda124f8f0117019a02696b0002feb5fe5c019c07120008001b0000011617070623222734131617130a01072427363732163332361303360106800a0a27585b138a4f131701e3f2ff0011033d2e565182840115050712016c3d5d707dfd9d0369fcedfe78fed4061085540c26ca014102fa57000001003efff9042e072b001b0000123732150301363732170607050116170607262701071306232627134b6f660901da503b6807087cfecf01d91e0103525715fe0e5b02016b75030b0723086ffc3f0131430173453dc5fdfb243f4a0b0b2a02213dfe6f810178063200000000010038fff90224074a0010000000170316333236333217060724031336330110010e145d1c3322350a02bcfed705100562074a6dfac3da124f8f0117019a05356b000000010046fffa07410488002e00000106030623263512352627220003060726350a01353637161713122516173637041314030623263512352627220706048503110a6855100a9392fef432056667072e0d586a0710a8014fe55199ed015d05140a6855100a939286210292e6feb96508630166dffd11fe83fe205e090c6801cd01a24c5e01097afef801810707c0c2050afe44f2fe986508630166dffd11be2f00010046fffa047b0482001c00001726350a01353637161f01122504131403062326351235262722000306d86707240d586a0706a8014f015d05140a6855100a9392fef43205020c6801c301a24c5e01097af4016d070afe44f2fe986508630166dffd11fe83fe2a5e0000000002002dffe905160494000d0019000001171600131000052724000336000312051724133734242f0104026a4aca016d2bfec7fed735fefbfebc090e01195c17015b51013b4f0aff00bb33fec40494020dfee0fee0feeafecd13071a01410127e5012efddefeb2610a1e010b2fc7ee0f0129000000020045fde704db047c000a001e0000010600071714173600372601130607222703363716151712210413020005220369c0fe940a03d8ad013f1c06fd2b080a54670a2f075f6906ef0175015a0301fe74fec48303bc0cfe8c98567d0a010131f0d3fc64fe3b700477059d700a0972ef017112fe81fef8fe3414000000020027fddd060a0468000a002400002536003727342306000716001732363316170607240b0102212403120025321736333217130199c0016c0a03d8adfec11c0603d093222e19450701cffec4100beafe8bfea60301018c013c96581e4145131daf0c017e98567d01fecff0d3fdfe010d0a5a750328018a01b3fead12017f010801cc14262653fb8f000000010033000002fd0489001600001316173637041706072e0127060713062326270226353692630b41940112160247534243ab121a0e635a070c280e0489065d530b12c9590a01740a17a0fd6b7901720299c15d5900000000010045ffe904040499002000000117041706072e012322060714041307020523242734373216172437342427371202324501320e0446406d64919d0802b02e0538fe5b3afe70133c3ca3b8010b0afd3e1b023f04990215ac450d034a45547604febe58feea251ef547108e04079ead05fc3b012900000000010012ffff0378063e00210000011617062b01270312173637363332150205240b012322273637333537363316170702d95a05085c92bb0402b469121d52552cfeedfe810301405c08055a5d040c62550a010500075a5b01fd93fefc0905725a71fee30f0c01d002695b5a0701e4590762d5000001003500000474048b001c00000116151a0115060726270302052403341336331615021516173200133603d867072e0d586a0710a7feb1fea306140a6855100a9392010c320504870c68fe3dfe5e4c5e01097b0107fe79070a01c2f20169640863fe9adffd11017d01d65e0001001100040406048b001600002526270a01353637321613121736123633161714020306020f643fbaa10b544442706d3a34e0424e4a0ba1b9400401a401e901653a500a6efee4feea979002396e0a503afe9bfe17a4000001000800040643048b00270000003716171612173612363316171402030607262702270603060726270a013536373216121736123702ea41361e21ab3a35ae42444a0b8991445e643f744a4b73405d654392890b4a4442ab3b34ae21048407073037fdce979002396e0a503afe9bfe17a40101a401a9bfbffe57a40101a401e901653a500a6efdce979002393700000001001c000004000480001f00000901262736371617090136371617140709011615060726270901060726273637018dfedb4b010658493201110112314a57064cfee3012d4c06584931fee1feec32495806014b0245014d3b44650a0256fed7012956020a65443bfebcfea13a45650a02570148feb757020a65453a00010032fde30455048b0025000000052227263536373216333212110205240334133633161502151617320013363716151213100341fee398523d053e415150abbea8feb1fea3051e0a68551a0a9392010c390566671101fde502291b4b411b21012c01b5fe7f070a01bcf20169640863fe9adffd11017d01d65e090c68fe79fecbfe380001003200040396047c00150000010526273637211615140701211617060721263534370293fdf553030a5f0292691dfdbc020b53030a5ffd6e691e03b90111525b060f553a3cfd2a1157570912553a3c0000000001008702b00372040b00170000001506072627262322070607262736371617163b0132363703722da6754548342b3b153a2c012bc35b4946350427443b04023aca1107191a4a2c01113eaa050619198e070000ffff009cfdbd01a00480000b0004026e047ec00000020033ffe6040a074b002c003300001326031200251617133633161706070316170607262726270116173e0237161706040726270706232627343701060706071617e2a80701011e011413119b133c4201061278a5030258353e1214fed1262d8db82b474d0609feebdd604d431f3a2f062501876a627702093601207c012f011f0167150101018f5805613c2cfed326685305011c0706fd0b0c0101a56301046474f1050117a75504442c5603ee146880bf945300000000010007fff405a9074f003400000103053e01331617060407252627132627363f0126273637123736252017161506232e012706070603211617060705072516170607012c2802b3cc8948540101feefecfcde530d2c4c020756086203086d26a8b1013c0165a123075744c9b4c78477280150840c0682fe9507016a840c068202bafe120c01e9056a70d6010b078402391649460e6512534c090148b1ba0786273b59076402017a61fef801585c0a015e0202585b0b000000020100051202de05dc0007000f00000015062322353637041506232235363701d314536c0b52018113546c0b5205da6c5c773f14026c5c773f1400ffff0016031e0316074700630044ffed04882a3d266600430042005d0441200040000000000100570113039f02ff00060000132111072311215703480162fd1b02fffe1501018800000100340559029d060e000e000000170607060f01262736331617363702930a05446d6ed96903065d6767657a060e4c4d0c0d020106574f0701030e0002003c0376026805a2000b001700000122061514163332363534262732161514062322263534360153567b7a575778795673a2a47375a0a3055c7a5757787857577a46a37372a4a27474a200010028fff6044805b700200000010413140205253216171423262704072635362524110225040306232227371225025c019b35fafe7c010e91f5066f44d5fe696f67010183019c18fed9fef44c0a5d4c010244019a05b72bfe62e5feb2e912306257190c11190a6b6afcf1011f0113190afeee746a1f01832e000000010020fff7045705c50027000001041f010607041302052403363332121724370225060726353637363526270407140726273712250269011c3d0a088701150533fe16fe001a0e544262fb01492313fefd5e6c610bd0cb1186febd325e4c090149018f05c518ee3c9e7455feabfe5d2d04019847fefe140efb01140e070714545d1918c1720707c7460a145532012015000000000100d304f202ef0600000c0000001714070423262734373e013702ed0254feab363c01549dd92105f62c2e1b8f013231163b58010000000001009e02a0017b03830007000012373217140726279f646f09696c08037b086c7403016800000000010158fe3c02e90008001500002533141716170607262736333216173637262726272601b36f43820214acc70a04311e294b500e075132271908670433809d1101992f590805434c050b3021000000000100bd0000032705c1001200000017020306232627121106072627343f0136330312150529095e571137e36648132fe48b5905b740fe08fcc443033e033d0151f90c073d4825ba8c0000000004001bffee068a05ee0012001d0035003b00000017020306232627123506072627343f0136332516170601263d0136013601321702033716170623271706232627370607263d01360017000736371201a40e031b063e390c2596432f0d1f965c3a029b360603fdcc530202120601af4422021872420e152588030b3b3a0706c5c5451a01b31efead0693ac1805b02afeb1fdda2c02290227dfa508052830197b5d3704655afac30350214005063dfdfc47fefffec207063e4705a92b053d8c01230a5a1bc701e99dfeaeb91e0101490003001affee064005ee0012001d003e00000017020306232627123506072627343f0136332516170601263d0136013601161314060737321617140726270407272227363724352627060714232227362501a30e031b063e390c2596432f0d1f965c3a024c360603fdcc53020212060182ff30a3fdb05ea004482d84fef03b2b180d01fc01131bc0af47432a082e012505ab2afeb1fdda2c02290227dfa508052830197b5d3c04655afac30350214005063dfdd71cfef388e6980518402c0d11070417074c31aa9dbbb31007ab4c52f03100000000040020ffd5068a05d50027003f00450050000001161f0106071617020524033633321617363726270607263536373635262706071407262735362501321702033716170623271706232627370607263d0136001700073637120316170601263d0136013601b4c52a07065dc00323feadfe9e1218332644aee3180db3414b4308908c0c5ce02241350532011404084422021872420e152588030b3b3a0706c5c5451a01b31efead0693ac18e4360603fdcc530202120605c5109c28684c38e0feed1e03010c2faa0d09a5b50a05050e373d10107f4b050583270d0d3128bd0efe1d47fefffec207063e4705a92b053d8c01230a5a1bc701e99dfeaeb91e010149033404655afac30350214005063d00000000010000021e0001005801800006009000240037ff920024003a006c0024003cff920024005900a00024005a00a80024005c005d0029000ffc7f00290011fc4600290024007e002f0037fe7e002f0039fe6a002f003afe66002f003cfe47002f005c00a30033000ffb6100330011fb2800330024006200350037ff3f00350039ffbc0035003affbc0035003cff7d0037000ffda300370010fe5100370011fd6a0037001dfd6a0037001efd6a00370024003600370032ff2800370044fdf400370046fddc00370048fdd50037004c004700370052fdda00370055fdd400370056fdff00370058fde90037005afddf0037005cfddc0039000ffdd600390010ff3700390011fd9d0039001dff0b0039001eff0b00390024007a00390044ff2300390048ff100039004c003400390052fefe00390055ff8000390058ff7d0039005cff8b003a000ffdae003a0010ff34003a0011fdae003a001dff09003a001eff09003a0024005e003a0044ff13003a0048ff0e003a004c0032003a0052ff2f003a0055ff7e003a0058ff7b003a005cff89003c000ffd95003c0010fe7e003c0011fd95003c001dfeb1003c001efeb1003c00240076003c0044fe9b003c0048fe77003c004c0056003c0052fe98003c0053ff1e003c0054fe40003c0058ff22003c0059ff4700490048ff550049004900ee0055000ffe8000550011fe470059000ffe9d00590011fe64005a000fff15005a0011ff21005c000fffce005c0011ffce00000000002a01fe00010000000000000034000000010000000000010009003b00010000000000020007003400010000000000030016003b00010000000000040009003b0001000000000005002c005100010000000000060008007d0001000000000009000d0085000100000000000a003f0092000100000000000c001900d10003000104030002000c03160003000104050002001000ea0003000104060002000c00fa0003000104070002001001060003000104080002001001160003000104090000009601260003000104090001001601260003000104090002000e01bc0003000104090003003001ca0003000104090004001601260003000104090005006e01fa0003000104090009001a0144000300010409000a007e026800030001040a0002000c031600030001040b0002001002e600030001040c0002000c031600030001040e0002000c03340003000104100002000e02f60003000104130002001203040003000104140002000c03160003000104150002001003160003000104160002000c03160003000104190002000e032600030001041b00020010033400030001041d0002000c031600030001041f0002000c03160003000104240002000e034400030001042d0002000e035200030001080a0002000c03160003000108160002000c0316000300010c0a0002000c0316000300010c0c0002000c0316547970656661636520a92028796f757220636f6d70616e79292e20323030382e20416c6c20526967687473205265736572766564526567756c617251696b6b69205265673a56657273696f6e20312e303056657273696f6e20312e3030204d617263682032362c20323030382c20696e697469616c2072656c6561736551696b6b695265674a6f616e6e65205461796c6f725468697320666f6e74207761732063726561746564207573696e6720466f6e7443726561746f7220352e362066726f6d20486967682d4c6f6769632e636f6d687474703a2f2f7777772e6172742d6f662d712e636f2e7a61006f00620079010d0065006a006e00e9006e006f0072006d0061006c005300740061006e0064006100720064039a03b103bd03bf03bd03b903ba03ac005100610072006d00690063002000730061006e0073002000a900200028004a006f0061006e006e00650020005400610079006c006f00720020002d00200071006100620062006f006a006f0040007900610068006f006f002e0063006f006d002900200032003000300039002e00200041006c006c00200052006900670068007400730020005200650073006500720076006500640052006500670075006c00610072005100610072006d00690063002000730061006e0073003a00560065007200730069006f006e00200031002e00300030005100610072006d00690063002000730061006e0073002000560065007200730069006f006e00200031002e00300030003b0020004600650062007200750061007200790020003200300030003900200069006e0069007400690061006c002000720065006c0065006100730065005400680069007300200066006f006e00740020007700610073002000630072006500610074006500640020007500730069006e006700200046006f006e007400430072006500610074006f007200200035002e0036002000660072006f006d00200048006900670068002d004c006f006700690063002e0063006f006d004e006f0072006d00610061006c0069004e006f0072006d0061006c0065005300740061006e00640061006100720064004e006f0072006d0061006c006e0079041e0431044b0447043d044b0439004e006f0072006d00e1006c006e0065004e0061007600610064006e006f0041007200720075006e0074006100000002000000000000ff270096000000000000000000000000000000000000000000700000000100020003000400050006000700080009000a000b000c000d000e000f0010001100120013001400150016001700180019001a001b001c001d001e001f0020002100220023002400250026002700280029002a002b002c002d002e002f0030003100320033003400350036003700380039003a003b003c003d003e003f0040004100420043004400450046004700480049004a004b004c004d004e004f0050005100520053005400550056005700580059005a005b005c005d006100a300840085008e009d00a400da008301020103008d00c300de010400f500f400f607756e693030423207756e693030423307756e6930304239000000000001ffff0002
"
)
/* Quartus II 64-Bit Version 12.1 Build 177 11/07/2012 SJ Full Version */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Cfg)
		Device PartName(5SGXEA7K2F40) Path("./") File("./output_files/top.sof") MfrSpec(OpMask(1));
	P ActionCode(Ign)
		Device PartName(5SGXEA7K2F40) MfrSpec(OpMask(0));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;

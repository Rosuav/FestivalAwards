//Graph G&S Festival awards
//Can filter somewhat. May later gain grouping capabilities.

array(string) data=Stdio.read_file("FestivalAwards.txt")/"\n"-({""});

mapping(string:int) parse_data(mapping(string:string|int) options)
{
	int year; string award; //What we're currently getting data for
	int havewinner; //Set to 1 when we've seen a winner for this award.
	multiset(string) champions; //Names of companies who won the championship (1st/2nd/3rd place)
	mapping(string:int) graphdata=([]); //Collection of data to graph! This is what we're working for.
	foreach (data,string line)
	{
		if (line[0]!='\t') //Header line (either year or award)
		{
			if (int yr=(int)line) {year=yr; champions=(<>);}
			else award=line;
			havewinner=0;
			continue;
		}
		//Winner/nomination line. Split it on tabs, compress empty fields away,
		//and ensure that there are at least four fields addressable.
		array(string) line = line/"\t" - ({""}) + ({"","","",""});
		//Figure out what weight to assign this, based on the options.
		//Weight may end up 0, which will suppress the entry. All modifications
		//to weight MUST be multiplied together, to ensure that zero is "sticky".
		int weight=havewinner?options->nominationweight:options->winnerweight;
		havewinner=1;
		if (award=="*Champions*") champions[line[1]]=1;
		else weight*=champions[line[1]]?options->championweight:options->nonchampweight;
		if (options["suppress"+year]) weight=0;
		graphdata[line[options->countfield]]+=weight;
	}
	return graphdata;
}


int main()
{
	mapping ret=parse_data(([
		"winnerweight":3, //Set to 0 to count only nominations
		"nominationweight":1, //Set to 0 to count only winners
		"countfield":0, //0/1/2/3 = Show/Company/Role/Performer - what gets graphed
		"championweight":1, //Set to 0 to ignore champions (those who won 1st/2nd/3rd place that year)
		"nonchampweight":1, //Set to 0 to ignore non-champions
		//"suppress2013":1, //If nonzero, all data from the chosen year will be suppressed.
	]));
	//write("%O\n",ret);
	array(string) labels=indices(ret);
	array(float) weights=(array(float))sort(values(ret),labels);
	mapping graphdata=([
		"xsize":1024,"ysize":768,"fontsize":12,
		"data":({weights}),"xnames":labels,
	]);
	Image.Image graph=Graphics.Graph.bars(graphdata);
	Stdio.write_file("graph.png",Image.PNG.encode(graph));
	//write("%O\n",graphdata);
}

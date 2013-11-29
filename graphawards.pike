//Graph G&S Festival awards
//Can filter somewhat. May later gain grouping capabilities.

array(string) data=Stdio.read_file("FestivalAwards.txt")/"\n"-({""});
array(string) awards=Array.uniq(filter(data,lambda(string s) {return s[0]!='\t' && !(int)s && s!="*Champions*";}));

mapping(string:int) parse_data(mapping(string:mixed) options)
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
		//Identify the champions by year and company name (eg "South Anglia").
		//This isn't perfect, but since the competition is for amateur companies
		//only, and amateur companies don't usually perform multiple shows in a
		//single festival year, it should normally be safe.
		if (award=="*Champions*") champions[line[1]]=1;
		else weight*=champions[line[1]]?options->championweight:options->nonchampweight;
		if (options["suppress"+year]) weight=0;
		if (options->awardfilter) weight*=options->awardfilter[award];
		if (weight) foreach (line[options->countfield]/"/",string f) graphdata[f]+=weight;
	}
	return graphdata;
}

void http_graph_png(Protocols.HTTP.Server.Request r)
{
	if (mixed ex=catch {
		//Tidy up the incoming configuration. Most of the info we want is integers,
		//so cast them all the easy way; this won't work with an array of strings,
		//though, so pull that one out and patch it back in afterward (as a set).
		array(string) awardfilter=Array.arrayify(m_delete(r->variables,"award")||awards);
		mapping(string:mixed) info=(mapping(string:int))r->variables;
		info->awardfilter=(multiset(string))awardfilter;

		mapping(string:int) ret=parse_data(info);
		m_delete(ret,""); //Blank entries aren't very useful.
		array(string) labels=indices(ret);
		array(float) weights=(array(float))sort(values(ret),labels);
		if (info->limit) {labels=labels[<info->limit-1..]; weights=weights[<info->limit-1..];}
		mapping graphdata=([
			"xsize":info->xsize||1024,"ysize":info->ysize||768,
			"fontsize":info->fontsize||12,
			"data":({weights}),"xnames":labels,
		]);
		Image.Image graph=Graphics.Graph.bars(graphdata);
		r->response_and_finish((["type":"image/png","data":Image.PNG.encode(graph)]));
	})
	{
		werror("Unexpected exception! Input variables: %O\nException:\n%s\n---------------\n",r->variables,describe_backtrace(ex));
		r->response_and_finish((["error":500,"type":"text/plain","data":"Unexpected server error, please check log"]));
	}
}

void http_(Protocols.HTTP.Server.Request r)
{
	r->response_and_finish((["type":"text/html","data":sprintf(#"<!doctype html>
<html>
<head>
<title>International G&S Festival Awards</title>
</head>
<body>
<h2>International G&S Festival Awards</h2>
<p>Graph options:</p>
<form action='graph.png'>
<table>
<tr><td>Weight an award win at:</td><td><input name=winnerweight value=3></td></tr>
<tr><td>Weight a non-winning nomination at:</td><td><input name=nominationweight value=1></td></tr>
<tr><td>Weight that year's champions at:</td><td><input name=championweight value=1></td></tr>
<tr><td>Weight that year's non-champions at:</td><td><input name=nonchampweight value=1></td></tr>
<tr><td>Graph which attribute?</td><td><select name=countfield>
	<option value=0>Show (eg Pirates, Ruddigore)</option>
	<option value=1>Company (eg South Anglia, Savoynet)</option>
	<option value=2>Role (eg Elsie Maynard, Alexis)</option>
	<option value=3>Performer (eg Anne Slovin, Joan Self)</option>
</select></td></tr>
<tr><td>Restrict to some awards:</td><td><select multiple size=6 name=award>%{
	<option>%s</option>%}
</select></td></tr>
<tr><td>Show only the highest ranked how many:</td><td><input name=limit></td></tr>
</table>
<input type=submit value='Generate'>
</form>
<p>Note: For all weights, use 0 to suppress that entirely. For instance, setting the champions
weight to 0 will graph only those shows which did not win one of the top three places (the
champions and two runners-up), and setting the non-champions weight to 0 will graph only those
which did.</p>
<p>Limiting the number of results shown will help to keep the graph readable.</p>
</body>
</html>
",awards)]));
}

void http(Protocols.HTTP.Server.Request r)
{
	if (function f=this["http"+replace(r->not_query,({"/","."}),"_")]) f(r);
	else r->response_and_finish((["error":404,"data":"Not found","type":"text/plain"]));
}

int main(int argc,array(string) argv)
{
	if (argc>1 && sscanf(argv[1],"--port=%d",int port) && port)
	{
		Protocols.HTTP.Server.Port(http,port,"::");
		write("Now listening for queries on port %d.\n",port);
		return -1;
	}
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

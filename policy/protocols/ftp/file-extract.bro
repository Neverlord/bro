##! File extraction for FTP.

@load ftp/base
@load utils/conn_ids
@load utils/files

module FTP;

export {
	## Pattern of file mime types to extract from FTP entity bodies.
	const extract_file_types = /NO_DEFAULT/ &redef;

	## The on-disk prefix for files to be extracted from FTP-data transfers.
	const extraction_prefix = "ftp-item" &redef;
}

redef record Info += {
	## The file handle for the file to be extracted
	extraction_file:       file &log &optional;
	
	extract_file:          bool &default=F;
	num_extracted_files:   count &default=0;
};

redef enum Tag += { EXTRACTED_FILE };

event file_transferred(c: connection, prefix: string, descr: string,
			mime_type: string) &priority=3
	{
	local id = c$id;
	if ( [id$resp_h, id$resp_p] !in ftp_data_expected )
		return;
		
	local expected = ftp_data_expected[id$resp_h, id$resp_p];
	local s = expected$state;

	if ( extract_file_types in s$mime_type )
		{
		s$extract_file = T;
		add s$tags[EXTRACTED_FILE];
		++s$num_extracted_files;
		}
	}

event file_transferred(c: connection, prefix: string, descr: string,
			mime_type: string) &priority=-4
	{
	local id = c$id;
	if ( [id$resp_h, id$resp_p] !in ftp_data_expected )
		return;
		
	local expected = ftp_data_expected[id$resp_h, id$resp_p];
	local s = expected$state;
	
	if ( s$extract_file )
		{
		local suffix = fmt("%d.dat", s$num_extracted_files);
		local fname = generate_extraction_filename(extraction_prefix, c, suffix);
		local s$extraction_file = open(fname);
		if ( s$passive )
			set_contents_file(id, CONTENTS_RESP, fh);
		else
			set_contents_file(id, CONTENTS_ORIG, fh);
		}
	}

event log_ftp(rec: Info) &priority=-10
	{
	delete rec$extraction_file;
	delete rec$extract_file;
	}
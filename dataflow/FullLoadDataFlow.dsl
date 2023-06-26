parameters{
	Root as string,
	Container as string,
	EntityPath as string,
	ManifestName as string,
	EntitiyName as string,
	startExecution as string,
	endExecution as string
}
source(allowSchemaDrift: true,
	validateSchema: false,
	inferDriftedColumnTypes: true,
	ignoreNoFilesFound: true,
	modifiedAfter: (toTimestamp($endExecution,'yyyy-MM-dd\'T\'HH:mm:ss')
),
	modifiedBefore: (toTimestamp($startExecution,'yyyy-MM-dd HH:mm:ss')),
	entity: ($EntitiyName),
	format: 'cdm',
	manifestType: 'manifest',
	manifestName: ($ManifestName),
	entityPath: ($EntityPath),
	local: true,
	folderPath: ($Container),
	fileSystem: ($Root),
	dateFormats: ['yyyy-MM-dd'],
	timestampFormats: ['yyyy-MM-dd\'T\'HH:mm:ss'],
	preferredIntegralType: 'long',
	preferredFractionalType: 'decimal') ~> IDataSources
IDataSources derive(each(match(type=='string'), $$ = iifNull(toString($$), ''))) ~> derivedColumnNull
derivedColumnNull select(mapColumn(
		each(match(name!='SYSROWVERSIONNUMBER'),
			upper($$) = $$)
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> selectionofEmptyRecords
selectionofEmptyRecords sink(allowSchemaDrift: true,
	validateSchema: false,
	deletable:false,
	insertable:true,
	updateable:false,
	upsertable:false,
	format: 'table',
	batchSize: 5000,
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true,
	saveOrder: 1) ~> DatabaseDMLOperation
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
	modifiedAfter: (toTimestamp($startExecution,'yyyy-MM-dd HH:mm:ss') 
),
	modifiedBefore: (toTimestamp($endExecution,'yyyy-MM-dd HH:mm:ss') ),
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
alterRowBeforeOperation derive(each(match(type=='string'), $$ = iifNull(toString($$), ''))) ~> derivedColumnNull
derivedColumnNull select(mapColumn(
		each(match(name!='SYSROWVERSIONNUMBER'),
			upper($$) = $$)
	),
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true) ~> selectionofEmptyRecords
IDataSources sort(asc(toTimestamp(byName('DataLakeModified_DateTime')), false),
	asc(toTimestamp(byName('LastProcessedChange_DateTime')), false),
	asc(iifNull(toString(byName('LSN')), toString(byName('Start_LSN'))), false),
	asc(toString(byName('Seq_Val')), false)) ~> sorting
sorting aggregate(groupBy(RECID = toString(byName('RECID'))),
	each(match(name!='RECID'), $$ = last($$))) ~> aggregationByRecId
aggregationByRecId alterRow(upsertIf(or(toString(byName('DML_Action'))=='INSERT',toString(byName('DML_Action'))=='AFTER_UPDATE')),
	deleteIf(toString(byName('DML_Action'))=='DELETE')) ~> alterRowBeforeOperation
selectionofEmptyRecords sink(allowSchemaDrift: true,
	validateSchema: false,
	deletable:false,
	insertable:true,
	updateable:false,
	upsertable:true,
	keys:[('RECID')],
	format: 'table',
	batchSize: 5000,
	skipDuplicateMapInputs: true,
	skipDuplicateMapOutputs: true,
	saveOrder: 1) ~> DatabaseDMLOperation
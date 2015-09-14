/**
 * Enables a custom adapter to obtain schema, read records, update records,
 * and delete records in an external system.
 *
 * @author Lawrence McAlpin (lmcalpin@salesforce.com)
 **/
global class CrossOrgDataSourceConnection extends DataSource.Connection {
    private RestClient restClient;
    private string remoteSObject = 'Account';

    global CrossOrgDataSourceConnection(DataSource.ConnectionParams connectionParams) {
        this.restClient = new RestClient(connectionParams);
    }

    /**
     *   Called when external object needs to get a list of
     *   schema from external data source, for example when the
     *   administrator clicks “Validate and Sync” in the user
     *   interface for the external data source.
     **/
    override global List<DataSource.Table> sync() {
        List < DataSource.Table > tables = new List < DataSource.Table > ();
        List < DataSource.Column > columns;
        columns = new List<DataSource.Column>();
        columns.add(DataSource.Column.text('ExternalId', 255));
        columns.add(DataSource.Column.url('DisplayUrl'));
        columns.add(DataSource.Column.text('Name', 255));
        columns.add(DataSource.Column.number('NumberOfEmployees', 18, 0));
        columns.add(DataSource.Column.text('Description', 4096));
        tables.add(DataSource.Table.get('xAccount', 'Name', columns));
        return tables;
    }

    /**
     *   Called to query and get results from the external
     *   system for SOQL queries, list views, and detail pages
     *   for an external object that’s associated with the
     *   external data source.
     *
     *   The QueryContext argument represents the query to run
     *   against a table in the external system.
     *
     *   Returns a list of rows as the query results.
     **/
    override global DataSource.TableResult query(DataSource.QueryContext c) {
        if (c.tableSelection.columnsSelected.size() == 1 && c.tableSelection.columnsSelected.get(0).aggregation == DataSource.QueryAggregation.COUNT) {
            integer count = execCount(getCountQuery(c));
            List < Map < String, Object >> countResponse = new List < Map < String, Object >> ();
            Map < String, Object > countRow = new Map < String, Object > ();
            countRow.put(
                c.tableSelection.columnsSelected.get(0).columnName,
                count);
            countResponse.add(countRow);
            return DataSource.TableResult.get(c,
                countResponse);
        } else if (c.queryMoreToken != null) {
            return execQueryMore(c);
        } else {
            return execQuery(c);
        }
    }

    /**
     *   Called to do a full text search and get results from
     *   the external system for SOSL queries and Salesforce
     *   global searches.
     *
     *   The SearchContext argument represents the query to run
     *   against a table in the external system.
     *
     *   Returns results for each table that the SearchContext
     *   requested to be searched.
     **/
    override global List<DataSource.TableResult> search(DataSource.SearchContext c) {
        return DataSource.SearchUtils.searchByName(c, this);
    }

    /**
     *   Called to insert or update rows in an external system.
     *
     *   The UpsertContext argument represents the values to be created
     *   or updated in the external system.
     *
     *   The UpsertResult List returned should have the same number of rows
     *   and be in the same order as the records that were created or updated.
     *   If a record was created, that record's UpsertResult should provide the
     *   record's ExternalID.
     **/
    override global List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext c) {
        List<DataSource.UpsertResult> results = new List<DataSource.UpsertResult>();
        for (Map<String,Object> row: c.rows) {
            Map<String,Object> updatedRows = new Map<String,Object>();
            String id = (String)row.get('ExternalId');
            for (String key : row.keySet()) {
                if (key.equals('ExternalId')) {
                    continue;
                } else if (key.equals('DisplayUrl')) {
                    continue;
                } else {
                    updatedRows.put(key, row.get(key));
                }
            }
            String jsonRecord = (String)JSON.serialize(updatedRows);
            try {
                if (id != null) {
                    restClient.patch('/sobjects/Account/' + id, jsonRecord);
                } else {
                    String rawResponse = restClient.post('/sobjects/Account/', jsonRecord);
                    Map<String,Object> response = (Map<String,Object>)JSON.deserializeUntyped(rawResponse);
                    id = (String)response.get('id');
                    throwException(rawResponse);
                }
                results.add(DataSource.UpsertResult.success(id));
            } catch (DataSource.DataSourceException e) {
                results.add(DataSource.UpsertResult.failure(id, e.getMessage()));
            }
        }
        return results;
    }

    /**
     *   Called to delete rows in an external system.
     *
     *   The DeleteContext argument represents the values to be deleted
     *   in the external system.
     *
     *   The DeleteResult List returned should have the same number of rows
     *   and be in the same order as the records that were deleted.
     **/
    override global List<DataSource.DeleteResult> deleteRows(DataSource.DeleteContext c) {
        List<DataSource.DeleteResult> results = new List<DataSource.DeleteResult>();
        for (String externalId: c.externalIds) {
            try {
                restClient.del('/sobjects/' + remoteSObject + '/' + externalId);
                results.add(DataSource.DeleteResult.success(externalId));
            } catch (DataSource.DataSourceException e) {
                results.add(DataSource.DeleteResult.failure(externalId, e.getMessage()));
            }
        }
        return results;
    }

    private DataSource.TableResult execQuery(DataSource.QueryContext c) {
        string soqlQuery = getSoqlQuery(c);
        String jsonResponse = restClient.query(soqlQuery);
        return parseQueryResponse(c, jsonResponse);
    }

    private DataSource.TableResult execQueryMore(DataSource.QueryContext c) {
        String jsonResponse = restClient.queryMore(c.queryMoreToken);
        return parseQueryResponse(c, jsonResponse);
    }

    private DataSource.TableResult parseQueryResponse(DataSource.QueryContext c, String jsonResponse) {
        Map<String,Object> response = (Map<String,Object>)JSON.deserializeUntyped(jsonResponse);
        integer totalSize = (integer) response.get('totalSize');
        string queryMoreToken = (string) response.get('nextRecordsUrl');
        List<Object> queryResultRows = (List<Object>) response.get('records');
        List < Map <String, Object>> rows = new List < Map < String, Object >>();
        for (Object queryResultRowObj: queryResultRows) {
            Map<String,Object> queryResultRow = (Map<String,Object>)queryResultRowObj;
            Map<String,Object> row = new Map < String, Object > ();
            row.put('Name', queryResultRow.get('Name'));
            row.put('NumberOfEmployees', queryResultRow.get('NumberOfEmployees'));
            row.put('Description', queryResultRow.get('Description'));
            row.put('ExternalId', queryResultRow.get('Id'));
            row.put('DisplayUrl', URL.getSalesforceBaseUrl().toExternalForm() + '/' + queryResultRow.get('Id'));
            rows.add(row);
        }
        return DataSource.TableResult.get(true, null, c.tableSelection.tableSelected, rows, totalSize, queryMoreToken);
    }

    private integer execCount(string soqlQuery) {
        String jsonResponse = restClient.query(soqlQuery);
        Map<String,Object> response = (Map<String,Object>)JSON.deserializeUntyped(jsonResponse);
        Integer totalCount = (Integer)response.get('totalSize');
        return totalCount;
    }

    private string getCountQuery(DataSource.QueryContext c) {
        string baseQuery = 'SELECT COUNT() FROM ' + remoteSObject;
        string filter = getSoqlFilter('', c.tableSelection.filter);
        if (filter.length() > 0) return baseQuery + ' WHERE ' + filter;
        return baseQuery;
    }

    private string getSoqlQuery(DataSource.QueryContext c) {
        string baseQuery = 'SELECT Id,Name,NumberOfEmployees,Description FROM ' + remoteSObject;
        string filter = getSoqlFilter('', c.tableSelection.filter);
        if (filter.length() > 0) return baseQuery + ' WHERE ' + filter;
        return baseQuery;
    }

    private string getSoqlFilter(string query, DataSource.Filter filter) {
        if (filter == null) {
            return query;
        }
        string append;
        DataSource.FilterType type = filter.type;
        List < Map < String, Object >> retainedRows = new List < Map < String, Object >> ();
        if (type == DataSource.FilterType.NOT_) {
            DataSource.Filter subfilter = filter.subfilters.get(0);
            append = getSoqlFilter('NOT', subfilter);
        } else if (type == DataSource.FilterType.AND_) {
            append = getSoqlFilterCompound('AND', filter.subfilters);
        } else if (type == DataSource.FilterType.OR_) {
            append = getSoqlFilterCompound('OR', filter.subfilters);
        } else {
            append = getSoqlFilterExpression(filter);
        }
        return query + ' ' + append;
    }

    private string getSoqlFilterCompound(string op, List < DataSource.Filter > subfilters) {
        string expression = ' (';
        boolean first = true;
        for (DataSource.Filter subfilter: subfilters) {
            if (first) first = false;
            else expression += ' ' + op + ' ';
            expression += getSoqlFilter('', subfilter);
        }
        expression += ') ';
        return expression;
    }

    private string getSoqlFilterExpression(DataSource.Filter filter) {
        string columnName = filter.columnName;
        string op;
        object expectedValue = filter.columnValue;
        if (filter.type == DataSource.FilterType.EQUALS) {
            op = '=';
        } else if (filter.type == DataSource.FilterType.NOT_EQUALS) {
            op = '<>';
        } else if (filter.type == DataSource.FilterType.LESS_THAN) {
            op = '<';
        } else if (filter.type == DataSource.FilterType.GREATER_THAN) {
            op = '>';
        } else if (filter.type == DataSource.FilterType.LESS_THAN_OR_EQUAL_TO) {
            op = '<=';
        } else if (filter.type == DataSource.FilterType.GREATER_THAN_OR_EQUAL_TO) {
            op = '>=';
        } else if (filter.type == DataSource.FilterType.STARTS_WITH) {
            return mapColumnName(columnName) + ' LIKE \'' + String.valueOf(expectedValue) + '%\'';
        } else if (filter.type == DataSource.FilterType.ENDS_WITH) {
            return mapColumnName(columnName) + ' LIKE \'%' + String.valueOf(expectedValue) + '\'';
        } else if (filter.type == DataSource.FilterType.CONTAINS) {
            return mapColumnName(columnName) + ' LIKE \'%' + String.valueOf(expectedValue) + '%\'';
        } else if (filter.type == DataSource.FilterType.LIKE_) {
            return mapColumnName(columnName) + ' LIKE \'' + String.valueOf(expectedValue) + '\'';
        } else {
            throwException('Implementing other filter types is left as an exercise for the reader: ' + filter.type);
        }
        return mapColumnName(columnName) + ' ' + op + ' ' + wrapValue(expectedValue);
    }

    private string mapColumnName(string apexName) {
        if (apexName.equalsIgnoreCase('ExternalId')) return 'Id';
        if (apexName.equalsIgnoreCase('DisplayUrl')) return 'Id';
        return apexName;
    }

    private object mapColumnValue(string apexName, object value) {
        // make sure we upsert with the correct data types
        if (apexName.equalsIgnoreCase('NumberOfEmployees')) return Integer.valueOf(value);
        return value;
    }

    private string wrapValue(object foundValue) {
        if (foundValue instanceof string) return '\'' + string.valueOf(foundValue) + '\'';
        return string.valueOf(foundValue);
    }
}

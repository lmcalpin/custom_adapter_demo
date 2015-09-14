/**
 * Utility class to aid in making callouts to another Salesforce org
 * from the CrossOrgDataSource Custom Adapter.
 *
 * @author Lawrence McAlpin (lmcalpin@salesforce.com)
 **/
public with sharing virtual class RestClient {
    private Http http;
    private DataSource.ConnectionParams connectionParams;

    public RestClient(DataSource.ConnectionParams connectionParams) {
        this.connectionParams = connectionParams;
        this.http = new Http();
    }

    public String query(String soql) {
        String encodedSoql = EncodingUtil.urlEncode(soql, 'UTF-8');
        String url = connectionParams.endpoint + 'services/data/v35.0/query?q=' + encodedSoql;
        String jsonResponse = sendGet(url);
        return jsonResponse;
    }

    public String queryMore(String nextRecordsUrl) {
        String url = connectionParams.endpoint + nextRecordsUrl;
        String jsonResponse = sendGet(url);
        return jsonResponse;
    }

    public String post(String recordUrl, String body) {
        String url = connectionParams.endpoint + 'services/data/v35.0' + recordUrl;
        String jsonResponse = sendPost(url, body);
        return jsonResponse;
    }

    public String patch(String recordUrl, String body) {
        String url = connectionParams.endpoint + 'services/data/v35.0' + recordUrl;
        String jsonResponse = sendPatch(url, body);
        return jsonResponse;
    }

    public void del(String recordUrl) {
        String url = connectionParams.endpoint + 'services/data/v35.0' + recordUrl;
        sendDelete(url);
    }

    private String sendGet(String url) {
        HttpRequest request = request(url, 'GET');
        HttpResponse response = http.send(request);
        validateStatusCode(url, response);
        return response.getBody();
    }

    private String sendPost(String url, String body) {
        HttpRequest request = request(url, 'POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        HttpResponse response = http.send(request);
        validateStatusCode(url, response);
        return response.getBody();
    }

    private String sendPatch(String url, String body) {
        HttpRequest request = request(url + '?_HttpMethod=PATCH', 'POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        HttpResponse response = http.send(request);
        validateStatusCode(url, response);
        return response.getBody();
    }

    private String sendDelete(String url) {
        HttpRequest request = request(url, 'DELETE');
        HttpResponse response = http.send(request);
        validateStatusCode(url, response);
        return response.getBody();
    }

    private HttpRequest request(String url, String method) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(url);
        request.setHeader('Authorization', 'Bearer ' + connectionParams.oauthToken);
        request.setMethod(method);
        return request;
    }

    private void validateStatusCode(String url, HttpResponse response ) {
        integer statusCode = response.getStatusCode();
        if (statusCode == 401) {
             throw new DataSource.OAuthTokenExpiredException();
        } else if (statusCode > 299) {
             throw new DataSource.DataSourceException('Error contacting ' + url + ': ' + response.getStatusCode() + ', body: ' + response.getBody());
        }
    }
}

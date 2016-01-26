/**
 * Defines the functional capabilities of our custom adapter, and
 * indicates the types of authentication that are required to access this
 * external system.  Factory for creating CrossOrgDataSourceConnection
 * class instances.
 *
 * @author Lawrence McAlpin (lmcalpin@salesforce.com)
 **/
global class CrossOrgDataSourceProvider extends DataSource.Provider {
    /**
     *   Declares the types of authentication that can be used
     *   to access the external system
     **/
    override global List<DataSource.AuthenticationCapability> getAuthenticationCapabilities() {
        List<DataSource.AuthenticationCapability> capabilities = new List<DataSource.AuthenticationCapability>();
        capabilities.add(DataSource.AuthenticationCapability.OAUTH);
        return capabilities;
    }

    /**
     *   Declares the functional capabilities that the
     *   external system supports.
     **/
    override global List<DataSource.Capability> getCapabilities() {
        List<DataSource.Capability> capabilities = new List<DataSource.Capability>();
        capabilities.add(DataSource.Capability.REQUIRE_ENDPOINT);
        capabilities.add(DataSource.Capability.ROW_QUERY);
        capabilities.add(DataSource.Capability.ROW_CREATE);
        capabilities.add(DataSource.Capability.ROW_UPDATE);
        capabilities.add(DataSource.Capability.ROW_DELETE);
        capabilities.add(DataSource.Capability.SEARCH);
        capabilities.add(DataSource.Capability.QUERY_PAGINATION_SERVER_DRIVEN);
        return capabilities;
    }

    /**
     *   Factory method that creates the associated DataSource.Connection class.
     **/
    override global DataSource.Connection getConnection(DataSource.ConnectionParams connectionParams) {
        return new CrossOrgDataSourceConnection(connectionParams);
    }
}

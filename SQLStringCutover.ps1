## Load the Citrix snap-insasnp Citrix.*
Disable configuration logging for the XD site:Set-LogSite -State Disabled## ## Clear the current Delivery Controller database connections## Note: AdminDBConnection must be the last commandSet-ConfigDBConnection -DBConnection $nullSet-AppLibDBConnection –DBConnection $null    #7.8 and newerSet-OrchDBConnection –DBConnection $null      #7.11 and newerSet-TrustDBConnection –DBConnection $null     #7.11 and newerSet-AcctDBConnection -DBConnection $nullSet-AnalyticsDBConnection -DBConnection $null # 7.6 and newerSet-HypDBConnection -DBConnection $nullSet-ProvDBConnection -DBConnection $nullSet-BrokerDBConnection -DBConnection $nullSet-EnvTestDBConnection -DBConnection $nullSet-SfDBConnection -DBConnection $nullSet-MonitorDBConnection -DataStore Monitor -DBConnection $null   #Monitoring DatabaseSet-MonitorDBConnection -DBConnection $null                      #Site DatabaseSet-LogDBConnection -DataStore Logging -DBConnection $null       #Logging DatabaseSet-LogDBConnection -DBConnection $null                          #Site DatabaseSet-AdminDBConnection -DBConnection $null -force

$ServerName = "CTX_76_DB"$SiteDBName = "CitrixCSPSite"$LogDBName = "CitrixCSPLogging"$MonitorDBName = "CitrixCSPMonitoring"$csSite = "Server=$ServerName;Initial Catalog=$SiteDBName;Integrated Security=True"$csLogging = "Server=$ServerName;Initial Catalog=$LogDBName;Integrated Security=True"$csMonitoring = "Server=$ServerName;Initial Catalog=$MonitorDBName;Integrated Security=True"
Set-AdminDBConnection -DBConnection $csSiteSet-ConfigDBConnection -DBConnection $csSiteSet-AcctDBConnection -DBConnection $csSiteSet-AnalyticsDBConnection -DBConnection $csSite # 7.6 and newerSet-HypDBConnection -DBConnection $csSite Set-ProvDBConnection -DBConnection $csSiteSet-AppLibDBConnection –DBConnection $csSite # 7.8 and newerSet-OrchDBConnection –DBConnection $csSite # 7.11 and newerSet-TrustDBConnection –DBConnection $csSite # 7.11 and newerSet-BrokerDBConnection -DBConnection $csSiteSet-EnvTestDBConnection -DBConnection $csSiteSet-SfDBConnection -DBConnection $csSiteSet-LogDBConnection -DBConnection $csSiteSet-LogDBConnection -DataStore Logging -DBConnection $nullSet-LogDBConnection -DBConnection $nullSet-LogDBConnection -DBConnection $csSiteSet-LogDBConnection -DataStore Logging -DBConnection $csLoggingSet-MonitorDBConnection -DBConnection $csSiteSet-MonitorDBConnection -DataStore Monitor -DBConnection $nullSet-MonitorDBConnection -DBConnection $nullSet-MonitorDBConnection -DBConnection $csSiteSet-MonitorDBConnection -DataStore Monitor -DBConnection $csMonitoringSet-LogSite -State Enabled## Test Database ConnectionsTest-AcctDBConnection -DBConnection $csSite
Test-AdminDBConnection -DBConnection $csSite
Test-AnalyticsDBConnection -DBConnection $csSite # 7.6 and newer
Test-AppLibDBConnection -DBConnection $csSite # 7.8 and newer
Test-BrokerDBConnection -DBConnection $csSite
Test-ConfigDBConnection -DBConnection $csSite
Test-EnvTestDBConnection -DBConnection $csSite
Test-HypDBConnection -DBConnection $csSite
Test-LogDBConnection -DBConnection $csSite
Test-LogDBConnection -DataStore Logging -DBConnection $csLogging
Test-MonitorDBConnection -DBConnection $csSite
Test-MonitorDBConnection -Datastore Monitor -DBConnection $csMonitoring
Test-OrchDBConnection -DBConnection $csSite # 7.11 and newer
Test-ProvDBConnection -DBConnection $csSite
Test-SfDBConnection -DBConnection $csSite
Test-TrustDBConnection -DBConnection $csSite # 7.11 and newer
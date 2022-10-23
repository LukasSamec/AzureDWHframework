using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Microsoft.Azure.KeyVault;
using Microsoft.Azure.Services.AppAuthentication;
using System.Net.Http;
using System.Data;
using Microsoft.AnalysisServices;

namespace AzureDWHFramework_TabularModelGenerator
{
    public static class RebuildAllTabularModels
    {
        [FunctionName("RebuildAllTabularModels")]
        public static async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,ILogger log)
        {
            MSSQLDatabaseConnector databaseConnector = null;
            string functionName = "RebuildAllTabularModels";

            try
            {
                string keyVaultUrl = req.Query["keyVault"];

                AzureServiceTokenProvider azureServiceTokenProvider = new AzureServiceTokenProvider();
                HttpClient httpClient = new HttpClient();

                KeyVaultClient keyVaultClient = new KeyVaultClient(new KeyVaultClient.AuthenticationCallback(azureServiceTokenProvider.KeyVaultTokenCallback), httpClient);

                string sqlConnString = keyVaultClient.GetSecretAsync(keyVaultUrl, "DatabaseConnectionString").Result.Value;
                string ssasConnString = keyVaultClient.GetSecretAsync(keyVaultUrl, "SSASConnectionString").Result.Value;

                string ssasDataSourceConnString = keyVaultClient.GetSecretAsync(keyVaultUrl, "SSASDataSourceConnectionString").Result.Value;

                string tenantId = keyVaultClient.GetSecretAsync(keyVaultUrl, "TenantID").Result.Value;
                string appId = keyVaultClient.GetSecretAsync(keyVaultUrl, "TabularModelGeneratorAppID").Result.Value;
                string appSecret = keyVaultClient.GetSecretAsync(keyVaultUrl, "TabularModelGeneratorAppSecret").Result.Value;
                string appUrl = keyVaultClient.GetSecretAsync(keyVaultUrl, "TabularModelGeneratorURL").Result.Value;


                databaseConnector = new MSSQLDatabaseConnector(sqlConnString);
                SSASDatabaseConnector ssasConnector = new SSASDatabaseConnector(ssasConnString);

                databaseConnector.InitConnection();
                Server server = await ssasConnector.InitConnection(appUrl, tenantId, appId, appSecret);

                databaseConnector.WriteFrameworkLog(functionName, "Info", "Rebuild all tabular models has started");

                DataTable tabularModels = databaseConnector.GetTabularModels();
                foreach (DataRow tabularModel in tabularModels.Rows)
                {
                    string modelName = tabularModel["TabularModelName"].ToString();
                    ssasConnector.RebuildTabularModel(modelName, ssasDataSourceConnString);
                    Database database = server.Databases.FindByName(modelName);
                    DataTable tables = databaseConnector.GetTablesForTabularModel(modelName);
                    ssasConnector.RebuildTabularModelTables(database, tables);

                    foreach (DataRow table in tables.Rows)
                    {
                        string tableName = table["TableName"].ToString();
                        DataTable columns = databaseConnector.GetColumnsForTableInTabularModel(modelName, tableName);
                        ssasConnector.RebuildTableColumns(database, columns, tableName);
                    }
                }

                databaseConnector.CloseConnection();
            }
            catch(Exception ex)
            {
                databaseConnector.WriteFrameworkLog(functionName, "Error", ex.Message);
                return new OkObjectResult("Rebuild all tabular models has ended with error \r\n " + ex.Message);
            }

            databaseConnector.WriteFrameworkLog(functionName, "Info", "Rebuild all tabular models has finished successfully");
            return new OkObjectResult("Rebuild all tabular models has finished successfully");
        }
    }
}

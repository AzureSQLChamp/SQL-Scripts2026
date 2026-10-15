👋 Welcome
Welcome to SQL-Scripts2026, a practical collection of SQL Server scripts maintained by AzureSQLChamp. This repository is intended to help database professionals perform common DBA tasks, investigate
production issues, monitor SQL Server environments, and deepen their understanding of SQL Server internals.
Whether you are learning SQL Server administration or supporting production systems, use these scripts as starting points for hands-on practice and carefully tested operational workflows.
Important: Scripts are provided for learning and adaptation.
Always review and test them in a non-production environment before
running them against business-critical systems.

🎯 What you'll find here
- Administration: useful database and instance-level checks.
- Backup and restore: backup operations and recovery-related
  scripts.
- Always On and HA/DR: Availability Group checks and
  troubleshooting helpers.
- Performance tuning: CPU, query, plan-cache, and performance
  investigation scripts.
- Monitoring: database-level monitoring, growth checks, and
  operational diagnostics.
- TempDB and parallelism: scripts for investigating TempDB
  behavior and parallel query execution.
- Query Store and Extended Events: tools to support query analysis
  and troubleshooting.
- Security: selected login and security administration utilities.
- Error-log analysis: scripts for reading and reviewing SQL Server
  error-log information.

📂 Repository guide
Browse the folders in the repository to find scripts by task.
  Folder                              Purpose
  AlwaysON-Scripts                  Availability Groups and
                                      high-availability diagnostics
  Backup and Restore                Backup and restore operations
  CPU-Scripts                       CPU and scheduler-related
                                      investigations
  DB-Growth                         Database, data-file, log-file, and
                                      free-space checks
  Database-Level-Monitoring         Database monitoring and operational
                                      checks
  Database-Scripts                  General database administration
                                      utilities
  Error Log                         SQL Server error-log investigation
  Extended Events                   Extended Events monitoring and
                                      troubleshooting
  LOG-File                          Transaction-log and virtual log
                                      file (VLF) utilities
  Parallelism                       Parallelism configuration and
                                      related diagnostics
  Performance-Scripts               Performance monitoring and
                                      troubleshooting
  Plan Cache                        Cached-plan and query-plan
                                      investigation
  Query Store                       Query Store analysis and
                                      troubleshooting
  Security-Scripts                  Login and security-related
                                      administration
  TEMPDB-Scripts                    TempDB monitoring and contention
                                  investigation
Folder contents may evolve as new scripts are added.
🚀 Getting started
1. Open the SQL-Scripts2026
   repository.
2. Browse the folder that matches the task you want to perform.
3. Open a .sql file and read its comments and prerequisites.
4. Review all statements, permissions, target databases, and
   environment-specific assumptions.
5. Test the script on a development or test instance.
6. Adapt it to your SQL Server version, security model, naming
   conventions, and operational standards.
7. Capture the results and validate them before using the script in a
   production workflow.
Clone the repository
git clone https://github.com/AzureSQLChamp/SQL-Scripts2026.git
cd SQL-Scripts2026
You can also use Code → Download ZIP on GitHub if you do not use Git
locally.
🧰 Compatibility and prerequisites
Compatibility depends on the individual script. Before execution,
confirm:
- The SQL Server version and edition supported by the script.
- Whether it targets an instance, a user database, or msdb /
  master / tempdb.
- Required permissions, such as VIEW SERVER STATE,
  VIEW DATABASE STATE, or elevated administrative rights.
- Whether SQL Server Agent, Query Store, Extended Events, or Always On
  Availability Groups are required.
- Whether the script assumes Windows Authentication, SQL
  Authentication, or a specific execution context.
- Whether any commands may change configuration, create objects,
  modify data, or consume significant resources.
Some scripts may require adjustment for newer SQL Server releases or
Azure SQL Database / Azure SQL Managed Instance. Do not assume that an
on-premises SQL Server script is directly compatible with every Azure
SQL service.
🔐 Safe-use checklist
Before running a script, ask:
- [ ] Have I read the entire script and understood its impact?
- [ ] Have I verified the server, database, and execution context?
- [ ] Have I checked the required permissions?
- [ ] Have I tested it outside production?
- [ ] Could it change data, configuration, security, or availability?
- [ ] Could it create heavy CPU, memory, I/O, blocking, or
  transaction-log activity?
- [ ] Do I have an approved change, backup, and rollback plan where
  needed?
- [ ] Have I removed credentials, tokens, server names, and other
  sensitive details before sharing output?
Scripts that use undocumented procedures, internal system objects, or
version-specific behavior should be treated as diagnostic examples and
validated carefully.
🧠 Suggested learning path
If you are building your SQL Server DBA skills, use the repository
alongside hands-on labs:
1. Core administration --- databases, files, configuration, and SQL
   Server Agent.
2. Backup and recovery --- backup strategy, restore validation,
   recovery models, and recovery objectives.
3. Monitoring --- error logs, blocking, waits, database growth, and
   transaction-log usage.
4. Performance tuning --- execution plans, indexing, statistics,
   Query Store, and plan-cache analysis.
5. TempDB and internals --- allocation, contention, parallelism,
   and workload behavior.
6. High availability and disaster recovery --- Always On
   Availability Groups, health checks, and failover validation.
7. Security and automation --- least privilege, repeatable
   operations, and controlled automation.
8. Azure SQL --- understand service-specific capabilities,
   limitations, monitoring, and migration considerations.
🤝 Contributions and feedback
Found an issue or have an improvement?
1. Open an issue describing the SQL Server version, scenario, and
   expected behavior.
2. Remove sensitive production information from logs and screenshots.
3. Where possible, include reproducible steps and sanitized sample
   output.
4. Submit a pull request with a clear description of the change and its
   testing.
Please do not include passwords, access tokens, private keys, customer
data, or confidential production details.
🎓 About AzureSQLChamp
AzureSQLChamp shares practical database administration knowledge,
troubleshooting examples, performance-tuning techniques, and hands-on
learning resources for SQL Server and Azure SQL professionals.
Explore the repository:
➡️ AzureSQLChamp /
SQL-Scripts2026
📬 Connect
- GitHub: AzureSQLChamp
- Repository:
  SQL-Scripts2026
For training or professional enquiries, add your preferred public
contact details here.

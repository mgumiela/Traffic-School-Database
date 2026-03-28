# Traffic School Database

Relational database system for managing a traffic school, including students, instructors, courses, and administrative processes.

## Overview

This project implements a complete database schema for a driving/traffic school. It includes data structures, constraints, business logic and access control mechanisms designed to ensure data integrity and consistency.

The system supports:
- student and instructor management
- course scheduling and participation
- administrative operations and reporting

## Architecture

The project is based on a PostgreSQL relational database and consists of:

- Schema definitions (schema.sql)
- Data population scripts (data.sql, archive.sql)
- Stored functions (functions.sql)
- Triggers (triggers.sql)
- Views (views.sql)
- Roles and permissions (roles.sql)
- Database dump (TSD.dump)

## Features

- Structured relational schema with constraints
- Business logic implemented via triggers and functions
- Views for simplified data access and reporting
- Role-based access control (RBAC)
- Preloaded sample data for testing

## Project Structure


```
documents/
├── schema.sql
├── data.sql
├── functions.sql
├── triggers.sql
├── views.sql
├── roles.sql
├── archive.sql
├── data_fixed_logic.sql
└── TSD.dump
```

## Getting Started

1. Create database:
createdb traffic_school

2. Load schema:
psql -d traffic_school -f documents/schema.sql

3. Load additional components:
psql -d traffic_school -f documents/functions.sql
psql -d traffic_school -f documents/triggers.sql
psql -d traffic_school -f documents/views.sql
psql -d traffic_school -f documents/roles.sql
psql -d traffic_school -f documents/data.sql

Alternative: restore from dump:
pg_restore -d traffic_school documents/TSD.dump

## Security and Integrity

- Constraints enforce data correctness
- Triggers implement business rules
- Roles restrict access based on responsibilities

## Future Improvements

- REST API layer (e.g. Flask / FastAPI)
- Integration with frontend dashboard
- Advanced analytics and reporting
- Audit logging for user actions

## Tech Stack

- PostgreSQL
- SQL (DDL, DML, PL/pgSQL)

-- Migration: drop legacy catalog_agents view
-- Completes T9 in .specs/refactors/03-public-dto-migration.md and T13 in .specs/refactors/01-document-consistency.md

drop view if exists public.catalog_agents cascade;

class AddAccountRecalculationProcedure < ActiveRecord::Migration[5.2]
  def up
    # Drop existing procedure.
    execute <<-SQL
      DROP PROCEDURE IF EXISTS compactor;
    SQL

    # Drop  to archive real liabilities.
    execute <<-SQL
      CREATE TABLE IF NOT EXISTS export_liabilities LIKE liabilities;
    SQL

    execute <<-SQL
      CREATE PROCEDURE compactor()
      BEGIN
        -- Declare variables.
        DECLARE job_id INT DEFAULT 0;

        -- Create Compact job
        INSERT INTO jobs (`description`, `state`, created_at, updated_at)
        VALUES ('compact', 'created', NOW(), NOW());

        SELECT LAST_INSERT_ID() INTO job_id;

        -- Save and compact liabilities.
        CREATE TEMPORARY TABLE squashed_liabilities AS
        SELECT NULL, code, currency_id, member_id, 'Job', job_id, SUM(debit) as debit, SUM(credit) AS credit, NOW() AS created_at, NOW() AS updated_at

        FROM liabilities
        GROUP BY code, currency_id, member_id;

        -- Exporting raw liabilities.
        INSERT INTO export_liabilities
        SELECT NULL, code, currency_id, member_id, reference_type, reference_id, debit, credit, created_at, updated_at
        FROM liabilities WHERE reference_type != 'Job';

        -- Squash the liabilities.
        TRUNCATE liabilities;
        INSERT INTO liabilities
        SELECT * FROM squashed_liabilities;

        -- Drop the temporaty table.
        DROP TEMPORARY TABLE IF EXISTS squashed_liabilities;

        -- Calculate balance of accounts.
        CREATE TEMPORARY TABLE accounts_main
        SELECT ac.member_id, ac.currency_id, SUM(lb.credit) - SUM(lb.debit) AS amount
        FROM accounts as ac JOIN liabilities as lb
        USING(member_id, currency_id) WHERE lb.code IN
        (
          SELECT code
          FROM operations_accounts
          WHERE `type` = 'liability' AND kind = 'main'
        )
        GROUP BY lb.code, lb.currency_id, lb.member_id;

        -- Calculate locked of accounts.
        CREATE TEMPORARY TABLE accounts_locked
        SELECT ac.member_id, ac.currency_id, SUM(lb.credit) - SUM(lb.debit) AS amount
        FROM accounts as ac JOIN liabilities as lb
        USING(member_id, currency_id) WHERE lb.code IN
        (
          SELECT code
          FROM operations_accounts
          WHERE `type` = 'liability' AND kind = 'locked'
        )
        GROUP BY lb.code, lb.currency_id, lb.member_id;

        -- Update accounts.
        UPDATE accounts
          INNER JOIN accounts_main USING(member_id, currency_id)
          INNER JOIN accounts_locked USING(member_id, currency_id)
        SET
          accounts.balance = accounts_main.amount,
          accounts.locked = accounts_locked.amount,
          accounts.updated_at = NOW();

        -- Set job state and rows affected.
        IF (ROW_COUNT() != 0 AND job_id != 0) THEN
          UPDATE jobs SET `rows` = ROW_COUNT(), `state` = 'succeed' WHERE id = job_id;
        ELSE
          UPDATE jobs SET `rows` = ROW_COUNT(), `state` = 'failed' WHERE id = job_id;
        END IF;

        DROP TEMPORARY TABLE IF EXISTS accounts_main;
        DROP TEMPORARY TABLE IF EXISTS accounts_locked;
      END
    SQL
  end

  def down
    execute <<-SQL
      DROP TABLE IF EXISTS export_liabilities;
    SQL

    execute <<-SQL
      DROP PROCEDURE IF EXISTS compactor;
    SQL
  end
end

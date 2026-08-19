CREATE TABLE IF NOT EXISTS assets (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    hostname    VARCHAR(64) NOT NULL,
    ip_address  VARCHAR(45) NOT NULL,
    role        VARCHAR(32) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO assets (hostname, ip_address, role) VALUES
    ('bastion', '172.30.10.10', 'jump host'),
    ('app01',   '172.30.20.20', 'application'),
    ('db01',    '172.30.20.30', 'database');

RENAME USER 'appuser'@'%' TO 'appuser'@'172.30.20.%';

REVOKE ALL PRIVILEGES ON inventory.* FROM 'appuser'@'172.30.20.%';
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory.* TO 'appuser'@'172.30.20.%';

CREATE USER IF NOT EXISTS 'readonly'@'172.30.20.%' IDENTIFIED BY 'readonlylab';
GRANT SELECT ON inventory.* TO 'readonly'@'172.30.20.%';

FLUSH PRIVILEGES;

const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const path = require('path');
const fs = require('fs');

/**
 * SSH Client for executing commands on Raspberry Pi
 */
class SSHClient {
  constructor(options = {}) {
    this.host = options.host || process.env.RASPBERRY_PI_IP || '192.168.0.214';
    this.user = options.user || process.env.RPI_SSH_USER || 'digioptics_od';
    this.port = options.port || process.env.RPI_SSH_PORT || 22;
    this.privateKeyPath = options.privateKeyPath || 
      process.env.RPI_SSH_KEY_PATH || 
      path.join(__dirname, '../.ssh/id_ed25519');
    this.strictHostKeyChecking = options.strictHostKeyChecking !== false;
  }

  /**
   * Build SSH command with proper options
   */
  buildSSHCommand(command) {
    const keyOption = fs.existsSync(this.privateKeyPath) 
      ? `-i ${this.privateKeyPath}` 
      : '';
    
    const strictHostKey = this.strictHostKeyChecking 
      ? '' 
      : '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null';
    
    return `ssh ${keyOption} ${strictHostKey} -p ${this.port} ${this.user}@${this.host} "${command.replace(/"/g, '\\"')}"`;
  }

  /**
   * Execute a command on RPi via SSH
   * @param {string} command - Command to execute
   * @param {object} options - Execution options
   * @returns {Promise<{stdout: string, stderr: string, code: number}>}
   */
  async execute(command, options = {}) {
    const { timeout = 30000, cwd } = options;
    
    try {
      const sshCommand = this.buildSSHCommand(command);
      console.log(`🔐 SSH: ${this.user}@${this.host} -> ${command}`);
      
      const { stdout, stderr } = await execAsync(sshCommand, {
        timeout,
        cwd: cwd || process.cwd(),
        maxBuffer: 1024 * 1024 * 10 // 10MB
      });

      return {
        success: true,
        stdout: stdout.trim(),
        stderr: stderr.trim(),
        code: 0
      };
    } catch (error) {
      return {
        success: false,
        stdout: error.stdout?.trim() || '',
        stderr: error.stderr?.trim() || error.message,
        code: error.code || 1
      };
    }
  }

  /**
   * Copy file from local to RPi
   * @param {string} localPath - Local file path
   * @param {string} remotePath - Remote file path on RPi
   * @returns {Promise<{success: boolean, message: string}>}
   */
  async copyFile(localPath, remotePath) {
    try {
      const keyOption = fs.existsSync(this.privateKeyPath) 
        ? `-i ${this.privateKeyPath}` 
        : '';
      
      const scpCommand = `scp ${keyOption} -o StrictHostKeyChecking=no ${localPath} ${this.user}@${this.host}:${remotePath}`;
      
      console.log(`📤 SCP: ${localPath} -> ${this.user}@${this.host}:${remotePath}`);
      
      const { stdout, stderr } = await execAsync(scpCommand, {
        timeout: 60000,
        maxBuffer: 1024 * 1024 * 10
      });

      return {
        success: true,
        message: 'File copied successfully',
        stdout: stdout.trim(),
        stderr: stderr.trim()
      };
    } catch (error) {
      return {
        success: false,
        message: error.message,
        stderr: error.stderr?.trim() || error.message
      };
    }
  }

  /**
   * Check if SSH connection is available
   * @returns {Promise<boolean>}
   */
  async testConnection() {
    const result = await this.execute('echo "SSH connection test"', { timeout: 5000 });
    return result.success && result.code === 0;
  }

  /**
   * Get system information from RPi
   * @returns {Promise<object>}
   */
  async getSystemInfo() {
    const commands = {
      hostname: 'hostname',
      uptime: 'uptime',
      disk: 'df -h / | tail -1',
      memory: "free -h | grep '^Mem:' | awk '{print $2, $3, $4}'",
      load: "uptime | awk -F'load average:' '{print $2}'"
    };

    const results = {};
    for (const [key, cmd] of Object.entries(commands)) {
      const result = await this.execute(cmd);
      results[key] = result.success ? result.stdout : null;
    }

    return results;
  }

  /**
   * Check if a service is running
   * @param {string} serviceName - Service name (e.g., 'camera-agent')
   * @returns {Promise<boolean>}
   */
  async isServiceRunning(serviceName) {
    const result = await this.execute(`systemctl is-active --quiet ${serviceName} && echo "active" || echo "inactive"`);
    return result.success && result.stdout.trim() === 'active';
  }

  /**
   * Restart a service on RPi
   * @param {string} serviceName - Service name
   * @returns {Promise<{success: boolean, message: string}>}
   */
  async restartService(serviceName) {
    const result = await this.execute(`sudo systemctl restart ${serviceName}`);
    return {
      success: result.success && result.code === 0,
      message: result.success ? `Service ${serviceName} restarted` : result.stderr
    };
  }

  /**
   * Get service logs
   * @param {string} serviceName - Service name
   * @param {number} lines - Number of lines to retrieve
   * @returns {Promise<string>}
   */
  async getServiceLogs(serviceName, lines = 50) {
    const result = await this.execute(`sudo journalctl -u ${serviceName} -n ${lines} --no-pager`);
    return result.success ? result.stdout : result.stderr;
  }
}

module.exports = SSHClient;


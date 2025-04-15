const express = require('express');
const winston = require('winston');
const { ElasticsearchTransport } = require('winston-elasticsearch');

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Configure Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'sample-app' },
  transports: [
    // Console transport for local debugging
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    
    // TCP transport to send logs to Logstash
    new winston.transports.Stream({
      stream: require('net').connect({
        host: process.env.LOGSTASH_HOST || 'localhost',
        port: process.env.LOGSTASH_PORT || 5000
      })
    })
    
    // Uncomment to use direct Elasticsearch transport instead of Logstash
    /*
    new ElasticsearchTransport({
      level: 'info',
      clientOpts: {
        node: process.env.ELASTICSEARCH_URL || 'http://localhost:9200'
      },
      indexPrefix: 'application'
    })
    */
  ]
});

// Log unhandled exceptions
logger.exceptions.handle(
  new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  })
);

// Middleware to log requests
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info({
      type: 'request',
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration,
      userAgent: req.get('User-Agent'),
      ip: req.ip
    });
  });
  
  next();
});

// Routes
app.get('/', (req, res) => {
  logger.info('Home page accessed');
  res.send('Sample App for ELK Stack Integration');
});

app.get('/info', (req, res) => {
  logger.info('This is an informational message');
  res.send('Info log generated');
});

app.get('/warn', (req, res) => {
  logger.warn('This is a warning message');
  res.send('Warning log generated');
});

app.get('/error', (req, res) => {
  logger.error('This is an error message', { 
    error: 'Sample Error', 
    code: 'ERR_SAMPLE' 
  });
  res.send('Error log generated');
});

app.get('/exception', (req, res) => {
  try {
    throw new Error('This is a sample exception');
  } catch (error) {
    logger.error('Exception occurred', { 
      error: error.message, 
      stack: error.stack 
    });
    res.status(500).send('Exception logged');
  }
});

// Generate random logs for demo purposes
app.get('/generate', (req, res) => {
  const count = parseInt(req.query.count) || 10;
  const types = ['info', 'warn', 'error'];
  const actions = ['login', 'logout', 'purchase', 'view', 'search'];
  
  for (let i = 0; i < count; i++) {
    const type = types[Math.floor(Math.random() * types.length)];
    const action = actions[Math.floor(Math.random() * actions.length)];
    const userId = Math.floor(Math.random() * 1000);
    
    logger[type](`User ${userId} performed ${action}`, {
      userId,
      action,
      result: type === 'error' ? 'failure' : 'success',
      processingTime: Math.floor(Math.random() * 500)
    });
  }
  
  res.send(`Generated ${count} random logs`);
});

// Start the server
app.listen(port, () => {
  logger.info(`Sample application started on port ${port}`);
});
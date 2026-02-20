import mongoose from 'mongoose';
import { logger } from './logger';
import { env } from './env';

export const connectDatabase = async (): Promise<void> => {
  try {
    const mongoUri = env.database.uri;
    
    logger.info(`Connecting to MongoDB...`);
    logger.debug(`MongoDB URI (masked): ${mongoUri.replace(/\/\/[^@]*@/, '//***:***@')}`);
    
    
    await mongoose.connect(mongoUri, {
      // Remove deprecated options - they're now defaults in newer versions
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });
    
    logger.info('Connected to MongoDB successfully');
    
    // Handle connection events
    mongoose.connection.on('error', (error) => {
      logger.error('MongoDB connection error:', error);
    });
    
    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB disconnected');
    });
    
    mongoose.connection.on('reconnected', () => {
      logger.info('MongoDB reconnected');
    });
    
  } catch (error) {
    logger.error('Failed to connect to MongoDB:', error);
    throw error;
  }
};

export const disconnectDatabase = async (): Promise<void> => {
  try {
    await mongoose.disconnect();
    logger.info('Disconnected from MongoDB');
  } catch (error) {
    logger.error('Error disconnecting from MongoDB:', error);
    throw error;
  }
};
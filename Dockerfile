# Stage 1: Build Stage
FROM --platform=linux/amd64 node:22-alpine as build

# Set the working directory
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the working directory
COPY app/package*.json ./

# Install all dependencies
RUN npm install

# Copy the rest of the application source code
COPY app .

# Run TypeScript build
RUN npm run build

# Stage 2: Production Image
FROM --platform=linux/amd64 node:22-alpine

# Set the working directory
WORKDIR /usr/src/app

# Copy node modules and build artifacts from the build stage
COPY --from=build /usr/src/app/node_modules ./node_modules
COPY --from=build /usr/src/app/package*.json ./
COPY --from=build /usr/src/app/dist ./dist

# Expose the application port
EXPOSE 3000

# Set environment variables for AWS credentials (optional for flexibility)
ENV AWS_REGION=${AWS_REGION}
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# Start the application
CMD ["node", "dist/index.js"]

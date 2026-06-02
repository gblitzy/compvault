# Cheerio-based crawler does not need a browser, so use the lightweight Node image.
FROM apify/actor-node:20

# Copy package files and install production dependencies first (better layer caching).
COPY package*.json ./

RUN npm --quiet set progress=false \
 && npm install --omit=dev --omit=optional \
 && echo "Installed NPM packages:" \
 && (npm list --omit=dev --all || true) \
 && echo "Node.js version:" \
 && node --version \
 && echo "NPM version:" \
 && npm --version

# Copy the rest of the source.
COPY . ./

CMD npm start --silent

FROM astral-sh/uv:python3.13-slim

WORKDIR /app

# Copy the pyproject.toml and lock file if exists
COPY pyproject.toml ./

# Install dependencies
RUN uv sync --no-dev

# Copy the backend source
COPY . .

# Expose port 8000
EXPOSE 8000

# Start uvicorn
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

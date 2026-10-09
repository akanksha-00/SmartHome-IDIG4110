# Smart Home API

Backend API for the Smart Home project.

The backend is built with FastAPI and currently uses JSON files as the persistence layer.

---

# Technology Stack

- Python
- FastAPI
- Pydantic
- Uvicorn
- UV
- JSON file storage
- Swagger / OpenAPI

Planned:

- MongoDB
- Database-backed repositories

---

# Prerequisites

Make sure you have:

- Python 3.14 or newer
- [UV](https://docs.astral.sh/uv/)

check the installation

python --version
uv --version

# Install FastAPI

I think you dont need to install Fastapi if you clone this repo, check it yourself

# Project Structure

smarthome-api/

    data/
      houses.json
      rooms.json
      devices.json

     src/
        smarthome_api/

            api/
                routes/
                   houses.py
                   rooms.py
                   devices.py
                   dashboard.py

            repositories/
                house_repository.py
                room_repository.py
                device_repository.py

            schemas/
                house.py
                room.py
                device.py
                dashboard.py

            services/
                house_service.py
                room_service.py
                device_service.py
                dashboard_service.py

            main.py

pyproject.toml
README.md

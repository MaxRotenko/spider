

# Spider: Distributed Engineering Environment Coordinator

## 1. Purpose
Spider is the central coordinator for a distributed engineering environment. It orchestrates complex engineering workflows by delegating specialized tasks to a network of independent agents, managing data flow, and consolidating results.

## 2. Core Components

*   **Manager (Orchestrator)**
    *   The central brain of the system. It accepts high-level user requests, decomposes them into atomic tasks, and assigns them to appropriate agents.
    *   Manages the state of the workflow, handles error recovery, and aggregates partial results into a final solution.
*   **Agents (Workers)**
    *   Stateless or semi-stateless microservices, each specializing in a specific domain (e.g., CAD modeling, computer vision, data processing). 
    *   Communicate with the Manager via the Request Queue. Each agent exposes a standardized API contract defining its input parameters, capabilities, and output format.
*   **Request Queue**
    *   A durable message broker (e.g., RabbitMQ, NATS, or Redis Streams) that decouples the Manager from the Agents.
    *   Ensures reliable task delivery, load balancing, and horizontal scalability of the agent pool.

## 3. Data Model
The system operates on a directed acyclic graph (DAG) of processing units. The fundamental data flow follows the structure:

`Object → Properties → Processing → Decision`

1.  **Object**: The primary entity (e.g., a 3D model file, an image from a camera, a sensor log).
2.  **Properties**: A structured set of metadata and extracted features (e.g., geometric constraints, detected objects, statistical anomalies).
3.  **Processing**: The execution of a specific algorithm or toolchain on the properties by an Agent.
4.  **Decision**: The actionable output or conclusion (e.g., a modified CAD file, a pass/fail signal for quality control, a generated G-code).

## 4. Agent Interaction Model (Example Workflow)
Agents are addressed by their functional roles. Below is an example of a distributed reverse-engineering task:

1.  **Manager** receives a request: "Analyze this broken plastic bracket and generate a printable replacement."
2.  **Manager** enqueues a task for the **"Thumbelina" (Дюймовочка)** agent. Her role is precision micro-analysis and measurement.
    *   *Input:* Photo set of the bracket.
    *   *Processing:* Uses **OpenCV** to detect edges and calculate dimensions.
    *   *Output:* A structured JSON file with critical dimensions and tolerances.
3.  **Manager** retrieves the output and enqueues a new task for the **"Da Vinci"** agent. His role is generative 3D modeling.
    *   *Input:* The JSON from Thumbelina.
    *   *Processing:* Generates a parametric model in **FreeCAD**, reinforcing stress points identified in the original.
    *   *Output:* An STL or STEP file.
4.  **Manager** enqueues a final task for the **"Hamster" (Хомяк)** agent. His role is resource management and logistics.
    *   *Input:* The STL file and available printer farm status.
    *   *Processing:* Slices the model, selects the optimal printer based on material and queue length, and submits the job.
    *   *Output:* A job confirmation and estimated time of arrival.

## 5. Integrations
Spider is designed as an integration hub. It does not reinvent domain-specific tools but provides a unified orchestration layer for them:

*   **FreeCAD**: For parametric CAD modeling and automated geometry generation via its Python API.
*   **OpenCV**: For real-time computer vision, object detection, and feature extraction.
*   **MCP (Model Context Protocol)**: For interfacing with Large Language Models (LLMs) to parse unstructured user requests, generate code for agents, or provide natural language summaries of technical results.
*   **Other Tools**: Architecture supports integration with KiCad (PCB design), Blender (visualization), and various sensor data streams via standard API adapters.

## 6. Architectural Principles

*   **Modularity**
    *   Agents are containerized (Docker) and communicate through strict, versioned interfaces. A new capability (e.g., a FEM analysis agent) can be added to the ecosystem without modifying the Manager or existing agents.
*   **Verifiability**
    *   Every `Decision` must be traceable to its source `Object` and `Processing` steps. The Manager maintains a complete audit trail (Job ID chain). All intermediate artifacts (models, datasets, logs) are stored immutably.
*   **Local-First Operation**
    *   The core queue and Manager can run on a local edge server or a single machine. Agents execute on local hardware (workstations, microcontrollers, local GPU servers). Cloud integration is treated as an optional extension for burst scaling or heavy computation, ensuring the system remains fully functional in air-gapped environments.
 
## 7. Component Interaction Diagram

The following diagram illustrates the data flow and interaction between the Manager, the Request Queue, and specialized Agents during a typical engineering task.

```
+------------------+      1. Submit Job      +------------------+
|   User / Client  | --------------------->  |                  |
+------------------+                         |      Manager     |
                                             | (Orchestrator)   |
+------------------+      4. Return Result   |                  |
|   User / Client  | <---------------------  +--------+---------+
+------------------+                                |
                                                    | 2. Enqueue Task
                                                    v
+------------------+                     +------------------+
|                  |   Request Queue     |                  |
|   External DB    | <-----------------> |  (RabbitMQ/NATS) |
|  / Artifacts     |   (Artifact IDs)    |                  |
+------------------+                     +--------+---------+
                                                  |
                                                  | 3. Dequeue Task (Parallel)
                                                  +------------------------+
                                                  |                        |
                                          +-------v-------+        +-------v-------+
                                          |               |        |               |
                                          |   "Thumbelina"|        |    "Da Vinci" |
                                          |   (Analysis)  |        |   (Modeling)  |
                                          +-------+-------+        +-------+-------+
                                                  |                        |
                                                  | 5. Report Status       | 5. Report Status
                                                  | (JSON dims)            | (STEP file)
                                                  +-----------+------------+
                                                              |
                                                      +-------v-------+
                                                      |               |
                                                      |   "Hamster"   |
                                                      | (Logistics)   |
                                                      +-------+-------+
                                                              |
                                                              | 6. Final Report
                                                              v
                                                 +------------------+
                                                 |                  |
                                                 |      Manager     |
                                                 | (Aggregates &    |
                                                 |  Marks Job Done) |
                                                 +------------------+
```

**Flow Description:**

1.  **Submission**: User submits a high-level job to the Manager.
2.  **Enqueue**: Manager decomposes the job and places the first atomic task (e.g., for "Thumbelina") into the Request Queue.
3.  **Dequeue**: An available agent instance pulls the task from the queue.
4.  **Execution & Reporting**: Agent processes the data (potentially storing heavy artifacts in the External DB) and reports the structured result back to the Manager.
5.  **Chaining**: Based on the result, the Manager enqueues the next dependent task (e.g., for "Da Vinci").
6.  **Aggregation**: Once the final agent ("Hamster") completes its work, the Manager aggregates all partial results, updates the job status to `COMPLETED`, and notifies the User.

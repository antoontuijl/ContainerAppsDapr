using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace TodoApp.Backend.Controllers
{
    public class Todo
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public bool Done { get; set; }
    }

    [Route("api/[controller]")]
    [ApiController]
    public class TodosController : ControllerBase
    {
        private readonly ILogger<TodosController> _logger;

        private static List<string> logs = new List<string>();

        public TodosController(ILogger<TodosController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IActionResult Get()
        {
            List<Todo> _todoList = new List<Todo>();

            _todoList.Add(new Todo
            {
                Id = 1,
                Name = "Learn JavaScript",
                Done = true,
            });
            _todoList.Add(new Todo
            {
                Id = 2,
                Name = "Learn React",
                Done = false
            });

            return Ok(_todoList);
        }

        [HttpGet("liveness")]
        public IActionResult Liveness()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Liveness {logs.Count}");
            if (logs.Count <= 10)
                return Ok();
            else
                return BadRequest();
        }

        [HttpGet("readiness")]
        public IActionResult Readiness()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Readiness {logs.Count}");
            return Ok();
        }

        [HttpGet("startup")]
        public IActionResult Startup()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Startup {logs.Count}");
            return Ok();
        }
    }
}

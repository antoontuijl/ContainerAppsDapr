using Dapr.Client;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Diagnostics;
using TodoApp.Frontend.Models;

namespace TodoApp.Frontend.Controllers
{
    public class Todo
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public bool Done { get; set; }
    }

    public class HomeController : Controller
    {
        const string storeName = "statestore";
        const string key = "counter";

        private readonly ILogger<HomeController> _logger;
        private static List<string> logs = new List<string>();

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public async Task<IActionResult> Index()
        {
            var daprClient = new DaprClientBuilder().Build();

            // DAPR state store building block. See DAPR docs.
            var counter = await daprClient.GetStateAsync<int>(storeName, key);
            counter++;
            await daprClient.SaveStateAsync(storeName, key, counter);
            ViewBag.Counter = counter;

            var port = Environment.GetEnvironmentVariable("DAPR_HTTP_PORT");

            HttpClient client = new HttpClient();
            var re = await client.GetAsync($"http://localhost:{port}/v1.0/invoke/todo-back/method/todos");
            var text = await re.Content.ReadAsStringAsync();
            ViewBag.Text = text + "," + re.StatusCode + ",";
            ViewBag.Todos = JsonConvert.DeserializeObject<List<Todo>>(text);

            return View();
        }

        public IActionResult Liveness()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Liveness {logs.Count}");
            if (logs.Count <= 10)
                return Ok();
            else
                return BadRequest();
        }
        public IActionResult Readiness()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Readiness {logs.Count}");
            return Ok();
        }
        public IActionResult Startup()
        {
            _logger.LogInformation($"{DateTime.UtcNow} -- Startup {logs.Count}");
            return Ok();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}

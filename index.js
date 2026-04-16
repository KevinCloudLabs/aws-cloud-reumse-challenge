//JavaScript Code
const counter = document.querySelector(".counter-number");

async function updateCounter() {
    try {
        let response = await fetch("https://25jdaer7rmerk6fdbc6du6wq5y0kfdpo.lambda-url.us-west-1.on.aws/");
        let data = await response.json();

        counter.innerHTML = `Views: ${data.views}`; // 👈 FIX
    } catch (error) {
        console.error(error);
        counter.innerHTML = "Error loading views";
    }
}

updateCounter();
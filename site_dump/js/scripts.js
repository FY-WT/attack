document.getElementById('lookupButton').addEventListener('click', async() => {
    const domain = document.getElementById('domain').value;
    const resultsDiv = document.getElementById('results');
    
    if (!domain) {
        // Show a message if the domain is not provided
        resultsDiv.innerHTML = 'Please enter a valid domain name.';
        return
    }
    // Display a placeholder message while fetching data
    resultsDiv.innerHTML = `Looking up DNS records for: <strong>${domain}</strong>...`;

    // Create the request payload with the domain as JSON
    const payload = { domain: domain };

    try {
        // Make the API request using axios and await the response
        const response = await axios.post('https://3q931syi7b.execute-api.us-east-1.amazonaws.com/dev/nslookup', payload, {
            headers: {
                'Content-Type': 'application/json'
            }
        });

        // Access the 'body' field directly from the response data
        const { ip_address, domain } = await response.data.body;

        if (ip_address && domain) {
            resultsDiv.innerHTML = `<strong>DNS Records for ${domain}:</strong><br>IP Address: ${ip_address}`;
        } else {
            resultsDiv.innerHTML = `No valid DNS records were found.`;
        }
    } catch (error) {
        resultsDiv.innerHTML = `Error fetching DNS records: ${error.message}`;
    }


});

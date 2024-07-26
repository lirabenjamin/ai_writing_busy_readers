import numpy as np
import pandas as pd
import random
import matplotlib.pyplot as plt
import seaborn as sns

def elo_update(rating1, rating2, k, outcome):
    expected1 = 1 / (1 + 10 ** ((rating2 - rating1) / 400))
    expected2 = 1 / (1 + 10 ** ((rating1 - rating2) / 400))
    new_rating1 = rating1 + k * (outcome - expected1)
    new_rating2 = rating2 + k * (1 - outcome - expected2)
    return new_rating1, new_rating2

def calculate_noise_probability(rating_diff, max_noise=1, std_dev=200, temperature=0.1):
    """
    Calculate the probability of making a mistake based on the rating difference.
    The closer the ratings, the higher the probability of making a mistake.
    """
    # Half of standard deviation as the midpoint
    x0 = std_dev / 2
    # Logistic function
    return max_noise / (1 + np.exp(temperature * (rating_diff - x0)))

def simulate_convergence(n, k, max_noise, temperature, max_iter=10000, optimize=True, neighborhood_size=10):
    true_ratings = np.random.normal(1000, 200, n)
    np.random.shuffle(true_ratings)
    elo_ratings = np.full(n, 1000.0)
    comparisons = 0
    correlations = []

    for iteration in range(max_iter):
        if optimize:
            i = np.random.choice(n)
            subset = np.argsort(np.abs(elo_ratings - elo_ratings[i]))[:neighborhood_size]
            j = np.random.choice(subset)
        else:
            i, j = np.random.choice(n, 2, replace=False)

        outcome = 1 if true_ratings[i] > true_ratings[j] else 0

        # Calculate noise probability based on the true rating difference
        rating_diff = abs(true_ratings[i] - true_ratings[j])
        noise_probability = calculate_noise_probability(rating_diff, max_noise, temperature=temperature)

        if random.random() < noise_probability:
            outcome = 1 - outcome

        elo_ratings[i], elo_ratings[j] = elo_update(elo_ratings[i], elo_ratings[j], k, outcome)
        comparisons += 1

        if iteration % 100 == 0:
            correlations.append(np.corrcoef(true_ratings, elo_ratings)[0, 1])

    return correlations

def run_simulations(n_sim_each, n_values, k_values, noise_levels, temperature_values, max_iter=5000, neighborhood_sizes=[10]):
    results = []
    params = []

    for n in n_values:
        for k in k_values:
            for max_noise in noise_levels:
                for temperature in temperature_values:
                    for neighborhood_size in neighborhood_sizes:
                        for _ in range(n_sim_each):
                            r = simulate_convergence(n, k, max_noise, temperature, max_iter=max_iter, optimize=True, neighborhood_size=neighborhood_size)
                            results.append(r)
                            params.append({'n': n, 'k': k, 'max_noise': max_noise, 'temperature': temperature, 'neighborhood_size': neighborhood_size})
    return results, params

def plot_results(results, params, max_iter=5000, step=100, output_file='convergence.png', plot_config=None):
    if plot_config is None:
        plot_config = {'color': 'n', 'linestyle': 'temperature'}

    x_values = np.arange(0, max_iter, step)
    
    # Get unique values for each plot attribute dynamically
    unique_values = {key: sorted(set(p[key] for p in params)) for key in plot_config.values()}
    
    # Generate color palette and linestyles
    color_palette = sns.color_palette("husl", len(unique_values[plot_config['color']]))
    linestyle_options = ['-', '--', '-.', ':']
    
    # Map values to colors and linestyles
    value_to_color = {val: color_palette[i % len(color_palette)] for i, val in enumerate(unique_values[plot_config['color']])}
    value_to_linestyle = {val: linestyle_options[i % len(linestyle_options)] for i, val in enumerate(unique_values[plot_config['linestyle']])}

    for i, r in enumerate(results):
        color_attr = plot_config['color']
        linestyle_attr = plot_config['linestyle']
        plt.plot(x_values, r, color=value_to_color[params[i][color_attr]], alpha=0.2, linestyle=value_to_linestyle[params[i][linestyle_attr]])

    avg_results = calculate_averages(results, params, x_values, unique_values, plot_config)

    for color_val in avg_results:
        for linestyle_val in avg_results[color_val]:
            plt.plot(x_values, avg_results[color_val][linestyle_val], color=value_to_color[color_val], label=f"{plot_config['color']} = {color_val}, {plot_config['linestyle']} = {linestyle_val}", linestyle=value_to_linestyle[linestyle_val])

    plt.axhline(y=0.7, color='black', linestyle='--')
    plt.title('Convergence of Elo Ratings')
    plt.xlabel('Iteration')
    plt.ylabel('Correlation')
    plt.legend()
    plt.tight_layout()
    plt.savefig(output_file, dpi=300)
    plt.close()

def calculate_averages(results, params, x_values, unique_values, plot_config):
    avg_results = {val: {} for val in unique_values[plot_config['color']]}
    for color_val in unique_values[plot_config['color']]:
        for linestyle_val in unique_values[plot_config['linestyle']]:
            filtered_results = [r for i, r in enumerate(results) if params[i][plot_config['color']] == color_val and params[i][plot_config['linestyle']] == linestyle_val]
            if filtered_results:
                avg_results[color_val][linestyle_val] = np.mean(filtered_results, axis=0)
    return avg_results

if __name__ == "__main__":
    n_sim_each = 10
    n_values = [300,900]
    k_values = [40]
    noise_levels = [1]
    temperature_values = [1]
    max_iter = 5000
    neighborhood_sizes = [10,900]

    results, params = run_simulations(n_sim_each, n_values, k_values, noise_levels, temperature_values, max_iter, neighborhood_sizes=neighborhood_sizes)
    
    # Example configuration: color by n, linestyle by temperature
    plot_config = {'color': 'n', 'linestyle': 'neighborhood_size'}
    
    # print iteration when the correlation reaches 0.7
    for i, r in enumerate(results):
        for j, corr in enumerate(r):
            if corr >= 0.7:
                print(f"n={params[i]['n']}, k={params[i]['k']}, max_noise={params[i]['max_noise']}, temperature={params[i]['temperature']}, neighborhood_size={params[i]['neighborhood_size']}, iteration={j}")
                break
    
    
    plot_results(results, params, max_iter, plot_config=plot_config)


results